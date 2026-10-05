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

  describe "売上の取り方" do
    it "ミニストップ 2026年2月期: 売上を営業総収入で取り、描く" do
      _, chart = profit_loss("S100Y4UH", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "売上原価", 51_425_000_000 ], [ "販売一般管理費", 43_972_000_000 ] ]
        expect(segments(credit)).to eq [ [ "売上", 91_788_000_000 ], [ "営業損失", -3_610_000_000 ] ]
      end
    end

    it "博報堂DYホールディングス 2026年3月期: 企業拡張タグの売上で描く" do
      _, chart = profit_loss("S100YHXU", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "売上原価", 454_965_000_000 ], [ "販売一般管理費", 361_361_000_000 ],
                                        [ "営業利益", 44_675_000_000 ] ]
        expect(segments(credit)).to eq [ [ "売上", 861_003_000_000 ] ]
      end
    end

    it "セーラー広告 2026年3月期: 取扱高ではなく企業拡張タグの売上で描き、左右の高さが合う" do
      _, chart = profit_loss("S100YEAK", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "売上原価", 494_774_000 ], [ "販売一般管理費", 1_753_215_000 ] ]
        expect(segments(credit)).to eq [ [ "売上", 2_224_849_000 ], [ "営業損失", -23_140_000 ] ]
        expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
      end
    end

    it "NTTドコモ 2020年3月期（IFRS）: 企業拡張タグの収益で描く" do
      _, chart = profit_loss("S100J54V", :consolidated)
      aggregate_failures do
        expect(chart.renderable).to be true
        expect(segments(chart.bars.last).first).to eq [ "収益", 4_651_290_000_000 ]
      end
    end

    {
      "S100B9WP" => "スリー・ディー・マトリックス 2017年4月期（研究開発費を別の行に載せている）",
      "S100YRPF" => "スカイマーク 2026年3月期（費用が企業拡張タグ）",
      "S100YF0X" => "リボミック 2026年3月期（費用が企業拡張タグ）",
      "S100XSQX" => "ラクオリア創薬 2025年12月期（費用が企業拡張タグ）"
    }.each do |doc_id, name|
      it "#{name}: 売上は取れるが、費用を差額でしか求められないため描かない" do
        require_xbrl_fixture(doc_id)
        Dir.mktmpdir do |work_dir|
          Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
        end
        fs = Disclosure::FinancialStatement.find_by!(is_primary: true)
        aggregate_failures do
          expect(fs.items_hash["pl.revenue"]).to be_present
          expect(Charts::BuilderRegistry.build_all(fs)[:profit_loss].renderable).to be false
        end
      end
    end
  end
end
