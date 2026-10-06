require "rails_helper"

# 売上を企業拡張タグだけで開示する会社も、売上高純利益率と総資産回転率をAPIで返す。
# 期待値は有報の金額（当期純利益、売上、期首・期末の総資産）から計算する
RSpec.describe "売上を企業拡張タグだけで開示する実有報の財務指標" do
  # docID => [名前, 当期純利益, 売上, 期首総資産, 期末総資産]（単位: 千円）
  {
    "S100YRPF" => [ "スカイマーク 2026年3月期", 1_638_000, 110_441_000, 103_888_000, 121_103_000 ],
    # 売上が小さく、売上高純利益率は約−38,000%になる。有報の数値どおりなのでそのまま返す
    "S100YF0X" => [ "リボミック 2026年3月期", -1_145_360, 3_000, 3_185_842, 2_976_215 ],
    "S100XSQX" => [ "ラクオリア創薬 2025年12月期（連結）", 273_115, 3_979_956, 9_655_482, 10_514_193 ]
  }.each do |doc_id, (name, profit, revenue, assets_begin, assets_end)|
    it "#{name}: 売上高純利益率と総資産回転率を返す", :aggregate_failures do
      require_xbrl_fixture(doc_id)
      Dir.mktmpdir do |dir|
        Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: dir)
      end

      result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
        query { financialReports(limit: 1, offset: 0) { financialIndicators {
          netProfitMargin { value status } assetTurnover { value status }
        } } }
      GRAPHQL
      expect(result["errors"]).to be_nil
      metrics = result.dig("data", "financialReports", 0, "financialIndicators")
      expect(metrics.fetch("netProfitMargin")).to include("status" => "AVAILABLE", "value" => be_within(1e-9).of(profit.to_f / revenue))
      expect(metrics.fetch("assetTurnover"))
        .to include("status" => "AVAILABLE", "value" => be_within(1e-9).of(revenue / ((assets_begin + assets_end) / 2.0)))
    end
  end
end
