require "rails_helper"

RSpec.describe "財務指標の実有報サンプル照合" do
  # 6対応形式 + 米国基準、連結/単体、損失、初年度連結、権利・非支配持分を含む33社。
  # 期待値は本体のExtractorではなく、別欄の経営指標サマリをXMLから直接読み照合する。
  samples = %w[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO S100YQ6Y S100YR8L
               S100YDJC S100YIHR S100YC7N S100YE63 S100Y9T5 S100Y90D S100XTDX S100YANQ
               S100YI2V S100YJB4 S100Y0DB S100YD29 S100YCL0 S100YE7T S100SO41
               S100XCO8 S100XTLJ S100YDP3 S100YGH5 S100YJHA
               S100YH8W S100YEGP S100YGFW S100YGOL S100YIW6]
  let(:query) do
    <<~GRAPHQL
      query { financialReports(limit: 100, offset: 0) {
        id financialIndicators {
          roe { value status } roa { value status } netProfitMargin { value status }
          assetTurnover { value status } financialLeverage { value status }
        }
      } }
    GRAPHQL
  end

  samples.each do |doc_id|
    it "#{doc_id} の全区分を取込み、別欄の金額・比率とAPIを照合する", :aggregate_failures do
      path = require_xbrl_fixture(doc_id)
      @raw = File.open(path) { |f| Nokogiri::XML(f) { |config| config.huge } }.root.element_children
      Dir.mktmpdir do |dir|
        Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: dir)
      end
      report = Disclosure::Report.find_by!(edinet_document_id: doc_id)
      expect(report.financial_statements.size).to eq(report.has_consolidated_statement ? 2 : 1)
      report.financial_statements.each { |statement| verify_statement(statement, doc_id) }

      response = FinancialStatementSchema.execute(query).to_h
      expect(response["errors"]).to be_nil
      expect(response.dig("data", "financialReports").size).to eq 1
      metrics = FinancialStatements::Indicators.build(report.primary_financial_statement)
      expected = metrics.to_h do |key, metric|
        [ key.to_s.camelize(:lower), { "value" => metric.value, "status" => metric.status.upcase } ]
      end
      expect(response.dig("data", "financialReports", 0, "financialIndicators")).to eq expected
    end
  end

  def summary(name, context, standard_only: true)
    node = @raw.find do |element|
      element.name == "#{name}SummaryOfBusinessResults" && element["contextRef"] == context &&
        (!standard_only || element.namespace&.href&.include?("/taxonomy/jpcrp/"))
    end
    value = node && BigDecimal(node.text, exception: false)
    return nil unless value
    { value: value, precision: BigDecimal("10") ** -Integer(node["decimals"]) }
  end

  def verify_statement(statement, doc_id)
    metrics = FinancialStatements::Indicators.build(statement)
    if statement.presentation_format == "unsupported"
      published = summary("RateOfReturnOnEquityUSGAAP", "CurrentYearDuration")
      expect(statement.disclosed_roe).to eq published&.fetch(:value)
      expect_metric(metrics[:roe], published&.fetch(:value))
      expect(metrics.values_at(:roa, :net_profit_margin, :asset_turnover, :financial_leverage).map(&:status)).to all(eq("missing_data"))
      return
    end
    suffix = statement.consolidated? ? "" : "_NonConsolidatedMember"
    ifrs = statement.accounting_standard_ifrs?
    duration = "CurrentYearDuration#{suffix}"
    profit_name = if ifrs
      "ProfitLossAttributableToOwnersOfParentIFRS"
    elsif statement.consolidated?
      "ProfitLossAttributableToOwnersOfParent"
    else
      "NetIncomeLoss"
    end
    profit = summary(profit_name, duration).fetch(:value)
    items = statement.items_hash
    expect(items[statement.consolidated? ? "pl.profit_attributable_to_owners" : "pl.profit"]).to eq profit
    asset_name = ifrs ? "TotalAssetsIFRS" : "TotalAssets"
    balances = %w[Prior1YearInstant CurrentYearInstant].map { |period| summary(asset_name, "#{period}#{suffix}")&.fetch(:value) }
    expect(items.values_at("bs.assets_begin", "bs.assets")).to eq balances
    average_assets = balances.sum / 2 if balances.none?(&:nil?)
    expect_metric(metrics[:roa], average_assets && profit / average_assets)

    # 照合側は企業拡張のサマリも読む（三菱商事単体: 本表Revenueは標準、サマリは独自タグ）。
    revenue_fact = %w[RevenueIFRS NetSales OperatingRevenue1 Revenues].filter_map { |name| summary(name, duration, standard_only: false) }.first
    revenue = revenue_fact&.fetch(:value)
    # ガス等の内訳合算とサマリの総額は、切捨て単位の合計だけ差が出る。
    revenue_error = revenue && (items.rounding_errors.fetch("pl.revenue") + revenue_fact[:precision])
    if revenue
      expect((items.fetch("pl.revenue") - revenue).abs).to be < revenue_error
    else
      expect(items["pl.revenue"]).to be_nil
    end
    margin_error = revenue && profit.abs * revenue_error / (revenue * (revenue - revenue_error))
    turnover_error = revenue_error && average_assets && revenue_error / average_assets
    expect_metric(metrics[:net_profit_margin], revenue && profit / revenue, tolerance: margin_error)
    expect_metric(metrics[:asset_turnover], revenue && average_assets && revenue / average_assets, tolerance: turnover_error)

    # 自己資本は、別欄の自己資本比率と照合。銀行等は切捨て開示なので1表示単位未満を許容。
    equity_ratio_name = ifrs ? "RatioOfOwnersEquityToGrossAssetsIFRS" : "EquityToAssetRatio"
    %w[Prior1YearInstant CurrentYearInstant].zip(%w[bs.equity_attributable_to_owners_begin bs.equity_attributable_to_owners], balances).each do |period, code, assets|
      ratio = summary(equity_ratio_name, "#{period}#{suffix}")
      next unless ratio && assets
      expect(items[code]).not_to be_nil
      expect(items[code].to_d / assets).to be_within(ratio[:precision]).of(ratio[:value]) if items[code]
    end
    disclosed_roe = summary(ifrs ? "RateOfReturnOnEquityIFRS" : "RateOfReturnOnEquity", duration)
    if doc_id == "S100YI2V" && statement.consolidated?
      # 初年度連結のROEは企業公表値で補完する。他の指標の期首は捏造しない。
      expect(metrics[:roe].value).to eq disclosed_roe[:value].to_f
      expect(metrics[:roe].source).to eq "disclosed"
      expect(metrics.values_at(:roa, :financial_leverage).map(&:status)).to all(eq("missing_data"))
    elsif doc_id == "S100YQ6Y" && !statement.consolidated?
      # イオン単体の開示値2.7%とは異なるが、本仕様は平均(635,287+911,005)/2百万を分母にする。
      expect(metrics[:roe].value).to be_within(1e-12).of(24_972.0 / 773_146)
      expect(disclosed_roe[:value]).to eq 0.027.to_d
    elsif disclosed_roe
      expect(metrics[:roe].status).to eq "available"
      expect(metrics[:roe].value).to be_within(disclosed_roe[:precision].to_f / 2 + 1e-7).of(disclosed_roe[:value].to_f)
    end
    if metrics.values.all? { |metric| metric.status == "available" }
      expect(metrics[:net_profit_margin].value * metrics[:asset_turnover].value)
        .to be_within(1e-12).of(metrics[:roa].value)
      expect(metrics[:roa].value * metrics[:financial_leverage].value)
        .to be_within(1e-12).of(metrics[:roe].value)
    end
  end

  def expect_metric(metric, expected, tolerance: nil)
    if expected.nil?
      expect(metric.status).to eq "missing_data"
      expect(metric.value).to be_nil
    else
      expect(metric.status).to eq "available"
      expect(metric.value).to be_within(tolerance ? tolerance.to_f + 1e-12 : 1e-12).of(expected.to_f)
    end
  end
end
