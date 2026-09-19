require "rails_helper"

RSpec.describe "財務指標の取込から公開APIまで" do
  # 一覧画面相当の全フィールドを最大件数で取得し、複雑度・深さ制限への適合も検証する。
  # backend単体のDocker/CIでも実行できるよう、frontendのファイルには依存させない。
  let(:query) { <<~GRAPHQL }
    query($limit: Int!, $offset: Int!) {
      financialReports(limit: $limit, offset: $offset) {
        id stockCode companyName fiscalYearStartDate fiscalYearEndDate accountingStandard consolidationType
        financialIndicators {
          roe { value status } roa { value status } netProfitMargin { value status }
          assetTurnover { value status } financialLeverage { value status }
        }
        balanceSheet { renderable note bars { label segments { key label amount signedAmount ratio colorRole tooltipLabel } } }
        profitLoss { renderable note bars { label segments { key label amount signedAmount ratio colorRole tooltipLabel } } }
        cashFlow { renderable note steps { key label amount kind colorRole } }
      }
    }
  GRAPHQL

  it "同じ有報の期首期末を保存し、連結の親会社帰属利益で計算した数値を返す" do
    xml = synthetic_xbrl_xml(dei: { has_consolidated: "true" }, facts: {
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
    Dir.mktmpdir do |dir|
      Ingestion::ReportIngester.new(client: FakeEdinetClient.new("S0000001" => xml))
                              .ingest(doc_id: "S0000001", work_dir: dir)
    end
    result = FinancialStatementSchema.execute(query, variables: { limit: 100, offset: 0 }).to_h
    expect(result["errors"]).to be_nil
    indicators = result.dig("data", "financialReports", 0, "financialIndicators")
    expect(indicators.transform_values { |metric| metric["value"] }).to eq(
      "roe" => 0.16, "roa" => 0.064, "netProfitMargin" => 0.08, "assetTurnover" => 0.8, "financialLeverage" => 2.5)
    expect(indicators.values.map { |metric| metric["status"] }).to all(eq("AVAILABLE"))
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
    expect(indicators["roe"]).to eq("value" => nil, "status" => "NOT_CALCULABLE")
    expect(indicators["roa"]).to eq("value" => 0.064, "status" => "AVAILABLE")
    expect(indicators["netProfitMargin"]).to eq("value" => nil, "status" => "MISSING_DATA")
  end
end
