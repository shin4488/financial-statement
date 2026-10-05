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

  it "KDDI 2025年3月期: 売上原価・販管費の合計である営業費用を積まず、差額は実際の損益計算書の残りと一致する" do
    _, chart = profit_loss("S100XVWE", :consolidated)
    debit, credit = chart.bars
    aggregate_failures do
      expect(segments(debit)).to eq [ [ "売上原価", 3_343_655_000_000 ], [ "販売費及び一般管理費", 1_429_465_000_000 ],
                                      [ "税引前利益", 1_073_418_000_000 ] ]
      # その他の収益・費用、持分法による投資利益、金融収益・費用などの純額
      expect(segments(credit)).to eq [ [ "収益", 5_835_525_000_000 ], [ "その他損益（純額）", 11_013_000_000 ] ]
    end
  end

  it "住友理工 2025年3月期: 符号が逆の営業費用（売上原価・販管費の合計）を積まない" do
    _, chart = profit_loss("S100VZJC", :consolidated)
    debit, credit = chart.bars
    aggregate_failures do
      expect(segments(debit)).to eq [ [ "売上原価", 527_581_000_000 ], [ "販売費及び一般管理費", 63_090_000_000 ],
                                      [ "その他損益（純額）", -4_027_000_000 ], [ "税引前利益", 38_633_000_000 ] ]
      expect(segments(credit)).to eq [ [ "収益", 633_331_000_000 ] ]
    end
  end

  it "ディー・エヌ・エー 2019年3月期: 負の値で付けた費用を、売上総利益で確かめて正の値で描き、左右の高さが合う" do
    _, chart = profit_loss("S100G4YH", :consolidated)
    debit, credit = chart.bars
    aggregate_failures do
      expect(segments(debit)).to eq [ [ "売上原価", 56_206_000_000 ], [ "販売費及び一般管理費", 56_931_000_000 ],
                                      [ "税引前利益", 18_069_000_000 ] ]
      expect(segments(credit)).to eq [ [ "収益", 124_116_000_000 ], [ "その他損益（純額）", 7_090_000_000 ] ]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end
end
