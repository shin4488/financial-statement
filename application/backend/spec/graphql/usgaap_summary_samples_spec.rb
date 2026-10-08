require "rails_helper"

# 米国基準の有報を、実XBRLの取込からAPIまで通して確かめる。
# 本表に標準タグがないため、経営指標の要約からCFと財務指標だけを出し、BS・PLは説明文を返す
RSpec.describe "米国基準の財務諸表（実XBRL）" do
  let(:query) do
    <<~GRAPHQL
      query { financialReports(limit: 1, offset: 0) {
        presentationFormat
        balanceSheet { renderable note }
        profitLoss { renderable note }
        cashFlow { renderable steps { key amount } }
        financialIndicators {
          roe { value status source } roa { value status source } netProfitMargin { value status source }
          assetTurnover { value status source } financialLeverage { value status source }
        }
      } }
    GRAPHQL
  end

  def report(doc_id)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
    result = FinancialStatementSchema.execute(query).to_h
    expect(result["errors"]).to be_nil
    result.dig("data", "financialReports", 0)
  end

  def metric(report, key) = report.dig("financialIndicators", key)

  it "キヤノン 2025年12月期: CFを描き、BS・PLは米国基準は非対応と説明する" do
    canon = report("S100XTLJ")
    aggregate_failures do
      expect(canon["presentationFormat"]).to eq "usgaap_summary"
      expect(canon["balanceSheet"]).to eq("renderable" => false, "note" => "貸借対照表: 米国基準は非対応です。")
      expect(canon["profitLoss"]).to eq("renderable" => false, "note" => "損益計算書: 米国基準は非対応です。")
      expect(canon["cashFlow"]["renderable"]).to be true
      expect(canon["cashFlow"]["steps"].map { |step| [ step["key"], step["amount"] ] }).to eq [
        [ "cashBegin", 501_565_000_000 ], [ "operating", 475_903_000_000 ], [ "investing", -237_450_000_000 ],
        [ "financing", -179_221_000_000 ], [ "cashEnd", 585_981_000_000 ]
      ]
    end
  end

  it "キヤノン 2025年12月期: ROEを親会社株主に帰属する持分で計算し、ROA・売上高純利益率・総資産回転率も出す" do
    canon = report("S100XTLJ")
    # 単位: 百万円。公表ROEは9.7%
    profit = 332_053.0
    assets = (5_766_246 + 6_135_044) / 2.0
    equity = (3_380_273 + 3_491_808) / 2.0
    revenue = 4_624_727.0
    aggregate_failures do
      expect(metric(canon, "roe")).to include("status" => "AVAILABLE", "source" => "CALCULATED")
      expect(metric(canon, "roe")["value"]).to be_within(1e-12).of(profit / equity)
      expect(metric(canon, "roe")["value"]).to be_within(0.0005).of(0.097)
      expect(metric(canon, "roa")["value"]).to be_within(1e-12).of(profit / assets)
      expect(metric(canon, "netProfitMargin")["value"]).to be_within(1e-12).of(profit / revenue)
      expect(metric(canon, "assetTurnover")["value"]).to be_within(1e-12).of(revenue / assets)
      expect(metric(canon, "financialLeverage")["value"]).to be_within(1e-12).of(assets / equity)
    end
  end

  it "ソニー 2021年3月期: 親会社株主に帰属する持分がないため、ROEは会社が公表した値を出し、ROAは計算する" do
    sony = report("S100LM4N")
    aggregate_failures do
      expect(sony["cashFlow"]["renderable"]).to be true
      expect(metric(sony, "roe")).to eq("value" => 0.242, "status" => "AVAILABLE", "source" => "DISCLOSED")
      expect(metric(sony, "roa")["value"]).to be_within(1e-12).of(1_171_776.0 / ((23_039_343 + 26_354_840) / 2.0))
      expect(metric(sony, "financialLeverage")).to include("status" => "MISSING_DATA")
    end
  end

  it "トヨタ自動車 2019年3月期: 要約のCFの3区分と現金残高で描く" do
    toyota = report("S100G1ZO")
    expect(toyota["cashFlow"]["steps"].map { |step| step["amount"] }).to eq [
      3_219_639_000_000, 3_766_597_000_000, -2_697_241_000_000, -540_839_000_000, 3_706_515_000_000
    ]
  end
end
