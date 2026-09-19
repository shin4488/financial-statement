require "rails_helper"

RSpec.describe "財務指標の取込から公開APIまで" do
  # 一覧画面相当の全フィールドを最大件数で取得し、複雑度・深さ制限への適合も検証する。
  # backend単体のDocker/CIでも実行できるよう、frontendのファイルには依存させない。
  let(:query) { <<~GRAPHQL }
    query($limit: Int!, $offset: Int!) {
      financialReports(limit: $limit, offset: $offset) {
        id stockCode companyName fiscalYearStartDate fiscalYearEndDate accountingStandard consolidationType
        financialIndicators {
          roe { value status source } roa { value status } netProfitMargin { value status }
          assetTurnover { value status } financialLeverage { value status }
        }
        balanceSheet { renderable note bars { label segments { key label amount signedAmount ratio colorRole tooltipLabel } } }
        profitLoss { renderable note bars { label segments { key label amount signedAmount ratio colorRole tooltipLabel } } }
        cashFlow { renderable note steps { key label amount kind colorRole } }
      }
    }
  GRAPHQL

  let(:xml) do
    synthetic_xbrl_xml(dei: { has_consolidated: "true" }, facts: {
      [ "jppfs_cor:Assets", "Prior1YearInstant" ] => 1_000,
      [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 1_500,
      [ "jppfs_cor:ShareholdersEquity", "Prior1YearInstant" ] => 350,
      [ "jppfs_cor:ValuationAndTranslationAdjustments", "Prior1YearInstant" ] => 50,
      [ "jppfs_cor:ShareholdersEquity", "CurrentYearInstant" ] => 650,
      [ "jppfs_cor:ValuationAndTranslationAdjustments", "CurrentYearInstant" ] => -50,
      [ "jppfs_cor:NetAssets", "CurrentYearInstant" ] => 900,
      [ "jppfs_cor:NetSales", "CurrentYearDuration" ] => 1_000,
      [ "jppfs_cor:ProfitLossAttributableToOwnersOfParent", "CurrentYearDuration" ] => 80,
      [ "jppfs_cor:ProfitLoss", "CurrentYearDuration" ] => 100
    })
  end

  def ingest_report
    Dir.mktmpdir do |dir|
      Ingestion::ReportIngester.new(client: FakeEdinetClient.new("S0000001" => xml))
                              .ingest(doc_id: "S0000001", work_dir: dir)
    end
  end

  it "同じ有報の期首期末を保存し、連結の親会社帰属利益で計算した数値を返す" do
    ingest_report
    result = FinancialStatementSchema.execute(query, variables: { limit: 100, offset: 0 }).to_h
    expect(result["errors"]).to be_nil
    indicators = result.dig("data", "financialReports", 0, "financialIndicators")
    expect(indicators.transform_values { |metric| metric["value"] }).to eq(
      "roe" => 0.16, "roa" => 0.064, "netProfitMargin" => 0.08, "assetTurnover" => 0.8, "financialLeverage" => 2.5)
    expect(indicators.values.map { |metric| metric["status"] }).to all(eq("AVAILABLE"))
  end

  context "計算用金額と異なる公表ROEがある場合" do
    let(:xml) do
      super().sub("</xbrli:xbrl>", '<jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults contextRef="CurrentYearDuration">0.2</jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults></xbrli:xbrl>')
    end

    it "両方の入力を保存し、公開APIは計算値を優先する" do
      ingest_report
      expect(Disclosure::FinancialStatement.find_by!(is_primary: true).disclosed_roe).to eq 0.2.to_d
      response = FinancialStatementSchema.execute(query, variables: { limit: 100, offset: 0 }).to_h
      expect(response["errors"]).to be_nil
      expect(response.dig("data", "financialReports", 0, "financialIndicators", "roe"))
        .to eq("value" => 0.16, "status" => "AVAILABLE", "source" => "CALCULATED")
    end
  end

  it "指標追加前の保存データを再取込すると、同じカードIDの公開APIが欠損から計算値に変わる" do
    ingest_report
    # 旧取込は期首残高・自己資本を保存していなかった状態を再現する。
    Disclosure::FinancialStatementItem.where(item_code: %w[
      bs.assets_begin bs.equity_attributable_to_owners bs.equity_attributable_to_owners_begin
    ]).delete_all
    before = FinancialStatementSchema.execute(query, variables: { limit: 30, offset: 0 }).to_h
    expect(before["errors"]).to be_nil
    card_before = before.dig("data", "financialReports", 0)
    expect(card_before.dig("financialIndicators", "roe", "status")).to eq("MISSING_DATA")
    expect(card_before.dig("financialIndicators", "roa", "status")).to eq("MISSING_DATA")

    expect { ingest_report }.not_to change(Disclosure::Report, :count)
    after = FinancialStatementSchema.execute(query, variables: { limit: 30, offset: 0 }).to_h
    expect(after["errors"]).to be_nil
    card_after = after.dig("data", "financialReports", 0)
    expect(card_after["id"]).to eq(card_before["id"])
    expect(card_after.dig("financialIndicators", "roe")).to eq("value" => 0.16, "status" => "AVAILABLE", "source" => "CALCULATED")
    expect(card_after.dig("financialIndicators", "roa")).to eq("value" => 0.064, "status" => "AVAILABLE")
  end

  it "期首がない企業の公表ROEを保存し、APIで出所を区別する" do
    disclosed_xml = synthetic_xbrl_xml(dei: { has_consolidated: "true" }, facts: {
      [ "jppfs_cor:Assets", "CurrentYearInstant" ] => 70_482_000_000,
      [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration" ] => "0.372"
    })
    Dir.mktmpdir do |dir|
      Ingestion::ReportIngester.new(client: FakeEdinetClient.new("S0000001" => disclosed_xml))
                              .ingest(doc_id: "S0000001", work_dir: dir)
    end
    result = FinancialStatementSchema.execute(query, variables: { limit: 100, offset: 0 }).to_h
    expect(result["errors"]).to be_nil
    metrics = result.dig("data", "financialReports", 0, "financialIndicators")
    expect(metrics["roe"]).to eq("value" => 0.372, "status" => "AVAILABLE", "source" => "DISCLOSED")
    expect(metrics["roa"]["status"]).to eq "MISSING_DATA"
  end

  it "データ欠損と分母0以下を別の状態で返し、カード全体をエラーにしない" do
    create(:disclosure_financial_statement, items_hash: {
      "bs.assets_begin" => 1_000, "bs.assets" => 1_500,
      "bs.equity_attributable_to_owners_begin" => -100, "bs.equity_attributable_to_owners" => 100,
      "pl.profit_attributable_to_owners" => 80
    })
    result = FinancialStatementSchema.execute(query, variables: { limit: 30, offset: 0 }).to_h
    expect(result["errors"]).to be_nil
    indicators = result.dig("data", "financialReports", 0, "financialIndicators")
    expect(indicators["roe"]).to eq("value" => nil, "status" => "NOT_CALCULABLE", "source" => nil)
    expect(indicators["roa"]).to eq("value" => 0.064, "status" => "AVAILABLE")
    expect(indicators["netProfitMargin"]).to eq("value" => nil, "status" => "MISSING_DATA")
  end
end
