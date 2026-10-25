require "rails_helper"

# 経営指標サマリの総資産を企業拡張タグだけで開示する会社（詳細タグ付けの義務化前のIFRS。ifrs_summary）も、ROA・総資産回転率・財務レバレッジをAPIで返す。
# 期待値は有報の金額（親会社の所有者に帰属する当期利益、売上収益、期首・期末の総資産と親会社所有者帰属持分）から計算する
RSpec.describe "総資産を企業拡張タグだけで開示する実有報の財務指標" do
  # docID => [名前, 当期利益, 売上収益, 期首総資産, 期末総資産, 期首持分, 期末持分]（単位: 百万円）
  {
    "S10096LR" => [ "ファーストリテイリング 2016年8月期", 48_052, 1_786_473, 1_163_706, 1_238_119, 750_937, 574_501 ],
    "S100BV2Q" => [ "ファーストリテイリング 2017年8月期", 119_280, 1_861_917, 1_238_119, 1_388_486, 574_501, 731_770 ],
    "S100ENUV" => [ "ファーストリテイリング 2018年8月期", 154_811, 2_130_060, 1_388_486, 1_953_466, 731_770, 862_936 ]
  }.each do |doc_id, (name, profit, revenue, assets_begin, assets_end, equity_begin, equity_end)|
    it "#{name}: ROA・総資産回転率・財務レバレッジを返す", :aggregate_failures do
      require_xbrl_fixture(doc_id)
      Dir.mktmpdir do |dir|
        UseCases::IngestReport.new(client: FixtureEdinetClient.new).call(doc_id: doc_id, work_dir: dir)
      end

      result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
        query { financialReports(limit: 1, offset: 0) { financialIndicators {
          roa { value status } assetTurnover { value status } financialLeverage { value status }
        } } }
      GRAPHQL
      expect(result["errors"]).to be_nil
      metrics = result.dig("data", "financialReports", 0, "financialIndicators")
      assets = (assets_begin + assets_end) / 2.0
      equity = (equity_begin + equity_end) / 2.0
      expect(metrics.fetch("roa")).to include("status" => "AVAILABLE", "value" => be_within(1e-9).of(profit / assets))
      expect(metrics.fetch("assetTurnover")).to include("status" => "AVAILABLE", "value" => be_within(1e-9).of(revenue / assets))
      expect(metrics.fetch("financialLeverage")).to include("status" => "AVAILABLE", "value" => be_within(1e-9).of(assets / equity))
    end
  end
end
