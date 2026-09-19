require "rails_helper"

RSpec.describe "公表ROEと平均残高によるROEが異なる実有報" do
  # 出典: 各有報の本表（利益・自己資本）と経営指標サマリ（公表ROE）。単位は円。
  # 公表値との一致を期待せず、入力金額、保存した公表値、APIが採る計算条件を別々に確認する。
  samples = [
    [ "S100YS8T", 1_894_000_000, 15_838_000_000, 17_710_000_000, "0.1069" ],
    [ "S100YSG1", 751_040_000, 7_171_896_000, 7_770_570_000, "0.097" ],
    [ "S100YRHX", 43_006_000_000, 1_498_222_000_000, 1_622_898_000_000, "0.0275" ],
    [ "S100YQR5", -5_967_000_000, 68_602_000_000, 63_659_000_000, "-0.094" ],
    [ "S100YR60", 9_084_000_000, 139_796_000_000, 145_491_000_000, "0.0636" ],
    [ "S100YXHA", 97_825_000, 1_426_822_000, 3_292_575_000, "0.0414" ],
    [ "S100YTAL", 471_000_000, 6_123_000_000, 6_597_000_000, "0.0742" ],
    [ "S100YTAR", -493_929_000, 1_976_068_000, 1_482_139_000, "-0.285" ]
  ]

  samples.each do |doc_id, profit, opening_equity, closing_equity, disclosed|
    it "#{doc_id} は公表値を保存しつつ、APIでは期首期末平均による計算値を返す", :aggregate_failures do
      require_xbrl_fixture(doc_id)
      Dir.mktmpdir do |dir|
        Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: dir)
      end
      fs = Disclosure::Report.find_by!(edinet_document_id: doc_id).primary_financial_statement
      profit_code = fs.consolidated? ? "pl.profit_attributable_to_owners" : "pl.profit"
      expect(fs.items_hash).to include(
        profit_code => profit,
        "bs.equity_attributable_to_owners_begin" => opening_equity,
        "bs.equity_attributable_to_owners" => closing_equity)
      expect(fs.disclosed_roe).to eq disclosed.to_d
      expect(fs.disclosed_roe_checked_at).to be_present

      result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
        query { financialReports(limit: 1, offset: 0) { financialIndicators { roe { value status source } } } }
      GRAPHQL
      expect(result["errors"]).to be_nil
      metric = result.dig("data", "financialReports", 0, "financialIndicators", "roe")
      expect(metric).to include("status" => "AVAILABLE", "source" => "CALCULATED")
      expect(metric.fetch("value")).to be_within(1e-12).of(profit * 2.0 / (opening_equity + closing_equity))
      expect(metric.fetch("value")).not_to eq disclosed.to_f
    end
  end
end
