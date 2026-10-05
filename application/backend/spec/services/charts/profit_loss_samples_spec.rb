require "rails_helper"

# 損益計算書のグラフを、実XBRLの取込（公開API）から組み立てて確かめる。
# 期待値は有報の損益計算書の金額で、棒の構成・名前・金額と左右の高さの一致を見る
RSpec.describe "損益計算書のグラフ（実XBRL）" do
  def profit_loss(doc_id, consolidation_type)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
    fs = Disclosure::FinancialStatement.find_by!(consolidation_type: consolidation_type, is_primary: true)
    [ fs, Charts::BuilderRegistry.build_all(fs)[:profit_loss] ]
  end

  def segments(bar) = bar.segments.map { |segment| [ segment.label, segment.signed_amount ] }

  it "大運 2026年3月期: 売上高と営業収入に同じ金額が付いていても、売上を2倍にせず描く" do
    fs, chart = profit_loss("S100YK5Y", :non_consolidated)
    debit, credit = chart.bars
    aggregate_failures do
      expect(fs.items_hash["pl.revenue"]).to eq 9_211_685_000
      expect(segments(debit)).to eq [ [ "売上原価", 8_499_995_000 ], [ "販売一般管理費", 364_352_000 ], [ "営業利益", 347_338_000 ] ]
      expect(segments(credit)).to eq [ [ "売上", 9_211_685_000 ] ]
    end
  end
end
