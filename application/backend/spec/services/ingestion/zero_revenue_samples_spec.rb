require "rails_helper"

# 売上がない会社の売上を、実XBRLの取込（公開API）で確かめる。
# 本表の売上の行と経営指標の要約の売上がどちらも「－」のときだけ、売上0として保存する
RSpec.describe "売上0の書類（実XBRL）" do
  def ingest(doc_id)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
  end

  {
    "S100ICLB" => "ヘリオス 2019年12月期",
    "S100YK16" => "ARCHION 2026年3月期",
    "S100Z4G9" => "キャンバス 2026年6月期"
  }.each do |doc_id, name|
    it "#{name}: 売上の行と要約の売上が「－」のため、売上0として保存する" do
      ingest(doc_id)
      items = Disclosure::FinancialStatement.find_by!(is_primary: true).items_hash
      expect(items.values_at("pl.revenue", "pl.summary_revenue")).to eq [ 0, 0 ]
    end
  end

  it "クックビズ 2022年11月期: 連結初年度で連結の損益計算書を作っておらず、すべての行が「－」のため、売上0にしない" do
    ingest("S100QBCW")
    expect(Disclosure::FinancialStatement.find_by!(consolidation_type: :consolidated).items_hash).not_to have_key("pl.revenue")
  end

  it "ヘリオス 2019年12月期: 売上高純利益率は算出できず、総資産回転率は0回になる" do
    ingest("S100ICLB")
    result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
      query { financialReports(limit: 1, offset: 0) { financialIndicators {
        netProfitMargin { value status } assetTurnover { value status }
      } } }
    GRAPHQL
    metrics = result.dig("data", "financialReports", 0, "financialIndicators")
    aggregate_failures do
      expect(result["errors"]).to be_nil
      expect(metrics.fetch("netProfitMargin")).to eq("value" => nil, "status" => "NOT_CALCULABLE")
      expect(metrics.fetch("assetTurnover")).to eq("value" => 0.0, "status" => "AVAILABLE")
    end
  end
end
