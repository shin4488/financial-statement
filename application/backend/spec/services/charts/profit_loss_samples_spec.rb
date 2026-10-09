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
      expect(segments(credit)).to eq [ [ "収益", 5_835_525_000_000 ], [ "その他の収益（純額）", 11_013_000_000 ] ]
    end
  end

  it "住友理工 2025年3月期: 符号が逆の営業費用（売上原価・販管費の合計）を積まない" do
    _, chart = profit_loss("S100VZJC", :consolidated)
    debit, credit = chart.bars
    aggregate_failures do
      expect(segments(debit)).to eq [ [ "売上原価", 527_581_000_000 ], [ "販売費及び一般管理費", 63_090_000_000 ],
                                      [ "その他の費用（純額）", -4_027_000_000 ], [ "税引前利益", 38_633_000_000 ] ]
      expect(segments(credit)).to eq [ [ "収益", 633_331_000_000 ] ]
    end
  end

  it "ディー・エヌ・エー 2019年3月期: 負の値で付けた費用を、売上総利益で確かめて正の値で描き、左右の高さが合う" do
    _, chart = profit_loss("S100G4YH", :consolidated)
    debit, credit = chart.bars
    aggregate_failures do
      expect(segments(debit)).to eq [ [ "売上原価", 56_206_000_000 ], [ "販売費及び一般管理費", 56_931_000_000 ],
                                      [ "税引前利益", 18_069_000_000 ] ]
      expect(segments(credit)).to eq [ [ "収益", 124_116_000_000 ], [ "その他の収益（純額）", 7_090_000_000 ] ]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "IFRSのPLの差額" do
    let(:warnings) { [] }

    before { allow(Sentry).to receive(:capture_message) { |message, **options| warnings << [ message, options ] } }

    # 同じ書類のBS・CFの照合の警告は、それぞれのspecで確かめる
    def profit_loss_warnings = warnings.select { |message, _| message.start_with?("profit and loss") }

    it "武田薬品 2026年3月期: 表示した費用があり、差額が費用側なら「その他の費用（純額）」になる" do
      _, chart = profit_loss("S100YB5L", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "売上原価", 1_571_588_000_000 ], [ "販売費及び一般管理費", 1_084_215_000_000 ],
                                        [ "その他の費用（純額）", -1_992_272_000_000 ] ]
        expect(segments(credit)).to eq [ [ "収益", 4_505_720_000_000 ], [ "税引前損失", -142_355_000_000 ] ]
      end
    end

    it "HOYA 2026年3月期: 売上原価・販管費のタグがなく、通常の費用がすべて差額に入るため「費用（純額）」になる" do
      _, chart = profit_loss("S100YD7J", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "費用（純額）", -620_081_000_000 ], [ "税引前利益", 327_668_000_000 ] ]
        expect(segments(credit)).to eq [ [ "収益", 947_749_000_000 ] ]
        expect(profit_loss_warnings).to be_empty
      end
    end

    it "三井物産 2026年3月期: 原価が標準タグでないため、原価を差額で求めず、差額に含めたまま描く" do
      _, chart = profit_loss("S100YAVT", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "販売費及び一般管理費", 902_130_000_000 ], [ "その他の費用（純額）", -12_006_036_000_000 ],
                                        [ "税引前利益", 1_087_056_000_000 ] ]
        expect(segments(credit)).to eq [ [ "収益", 13_995_222_000_000 ] ]
      end
    end

    it "ローソン 2023年2月期: 企業拡張タグの収益で、今までの差額の描き方で描く" do
      _, chart = profit_loss("S100QTB3", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "売上原価", 473_074_000_000 ], [ "販売費及び一般管理費", 462_998_000_000 ],
                                        [ "その他の費用（純額）", -17_179_000_000 ], [ "税引前利益", 47_134_000_000 ] ]
        expect(segments(credit)).to eq [ [ "収益", 1_000_385_000_000 ] ]
        expect(profit_loss_warnings).to be_empty
      end
    end

    it "トヨタ自動車 2026年3月期: 営業費用が売上原価・販管費の合計と一致しないまま積まずに描き、警告する" do
      # 営業費用の合計には、売上原価・販管費のほかに金融事業に係る金融費用の行が入っている
      _, chart = profit_loss("S100Y8NY", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "売上原価", 39_141_418_000_000 ], [ "販売費及び一般管理費", 4_697_524_000_000 ],
                                        [ "その他の費用（純額）", -1_693_014_000_000 ], [ "税引前利益", 5_152_996_000_000 ] ]
        expect(segments(credit)).to eq [ [ "収益", 50_684_952_000_000 ] ]
        expect(profit_loss_warnings).to eq [ [
          "profit and loss chart expenses do not reconcile",
          { level: :warning, fingerprint: [ "profit and loss chart expenses do not reconcile" ],
            extra: { doc_id: "S100Y8NY", consolidation_type: "consolidated", presentation_format: "ifrs_classified",
                     amounts: { "pl.cost_of_sales" => 39_141_418_000_000, "pl.sga" => 4_697_524_000_000,
                                "pl.operating_expenses" => 46_918_736_000_000 } } }
        ] ]
      end
    end

    it "Jトラスト 2020年12月期: 販管費と別の行の営業費用を積まずに描き、差額が収益の48.9%になるため警告する" do
      _, chart = profit_loss("S100L2D0", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "販売費及び一般管理費", 19_643_000_000 ], [ "その他の費用（純額）", -15_987_000_000 ] ]
        expect(segments(credit)).to eq [ [ "収益", 32_652_000_000 ], [ "税引前損失", -2_978_000_000 ] ]
        expect(debit.segments.find { |segment| segment.key == "otherNet" }.ratio).to eq(-48.9)
        expect(profit_loss_warnings.map(&:first)).to eq [ "profit and loss chart expenses do not reconcile" ]
        expect(profit_loss_warnings.dig(0, 1, :extra, :amounts)).to eq("pl.sga" => 19_643_000_000, "pl.operating_expenses" => 17_653_000_000)
      end
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

  describe "費用の描き方（日本基準）" do
    let(:warnings) { [] }

    before { allow(Sentry).to receive(:capture_message) { |message, **options| warnings << [ message, options ] } }

    # 同じ書類のBS・CFの照合の警告は、それぞれのspecで確かめる
    def profit_loss_warnings = warnings.select { |message, _| message.start_with?("profit and loss") }

    it "燦ホールディングス 2025年3月期: 原価に当たる営業費用と販管費を積み、左右の高さが合う" do
      _, chart = profit_loss("S100W6NE", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "営業費用", 24_216_000_000 ], [ "販売一般管理費", 3_246_000_000 ],
                                        [ "営業利益", 4_521_000_000 ] ]
        expect(segments(credit)).to eq [ [ "売上", 31_984_000_000 ] ]
        expect(profit_loss_warnings).to be_empty
      end
    end

    it "ジャックス 2020年3月期: 販管費ではなく、販管費と金融費用を含む営業費用の1段で描き、左右の高さが合う" do
      _, chart = profit_loss("S100IZ1U", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "営業費用", 142_104_000_000 ], [ "営業利益", 16_506_000_000 ] ]
        expect(segments(credit)).to eq [ [ "売上", 158_610_000_000 ] ]
        expect(profit_loss_warnings).to be_empty
      end
    end

    it "イオン九州 2024年2月期: 費用のタグでは左右が端数を超えてずれるため、1割以内のずれのまま描いて警告する" do
      _, chart = profit_loss("S100THV6", :consolidated)
      aggregate_failures do
        expect(segments(chart.bars.first)).to eq [ [ "売上原価", 358_509_000_000 ], [ "販売一般管理費", 141_425_000_000 ],
                                                   [ "営業利益", 10_382_000_000 ] ]
        expect(profit_loss_warnings).to eq [ [
          "profit and loss chart expenses do not reconcile",
          { level: :warning, fingerprint: [ "profit and loss chart expenses do not reconcile" ],
            extra: { doc_id: "S100THV6", consolidation_type: "consolidated", presentation_format: "jgaap_general",
                     amounts: { "pl.revenue" => 484_742_000_000, "pl.cost_of_sales" => 358_509_000_000,
                                "pl.sga" => 141_425_000_000, "pl.operating_profit" => 10_382_000_000 } } }
        ] ]
      end
    end
  end

  describe "売上0（売上の行が「－」か、行がない）" do
    it "ヘリオス 2019年12月期: 販管費と営業損失が一致するため、費用と営業損失の2本で描く" do
      _, chart = profit_loss("S100ICLB", :non_consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "販売一般管理費", 4_271_000_000 ] ]
        expect(segments(credit)).to eq [ [ "営業損失", -4_271_000_000 ] ]
      end
    end

    it "ARCHION 2026年3月期: 営業費用と営業損失が一致するため、費用と営業損失の2本で描く" do
      _, chart = profit_loss("S100YK16", :non_consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "営業費用", 73_000_000 ] ]
        expect(segments(credit)).to eq [ [ "営業損失", -73_000_000 ] ]
      end
    end

    it "窪田製薬ホールディングス 2019年12月期（IFRS）: 研究開発費・一般管理費の合計が営業損失と一致するため、費用と営業損失の2本で描く" do
      _, chart = profit_loss("S100IFQA", :consolidated)
      debit, credit = chart.bars
      aggregate_failures do
        expect(segments(debit)).to eq [ [ "研究開発費", 2_756_331_000 ], [ "一般管理費", 532_076_000 ] ]
        expect(segments(credit)).to eq [ [ "営業損失", -3_288_407_000 ] ]
        expect(credit.segments.first.ratio).to eq(-100.0)
      end
    end

    it "窪田製薬ホールディングス 2021年12月期（IFRS）: 営業損失にその他の営業収益が含まれ、費用の合計と一致しないため描かない" do
      fs, chart = profit_loss("S100NRX4", :consolidated)
      aggregate_failures do
        expect(fs.items_hash["pl.revenue"]).to eq 0
        expect(chart.renderable).to be false
      end
    end
  end

  {
    "S100VY3Q" => [ "中外炉工業 2025年3月期", :consolidated ],
    "S100O4KK" => [ "ベルク 2022年2月期", :consolidated ],
    "S100YF3V" => [ "帝国ホテル 2026年3月期", :consolidated ],
    "S100Y7MV" => [ "スパークス・グループ 2026年3月期", :consolidated ],
    "S100Z4G9" => [ "キャンバス 2026年6月期（売上0で、費用が企業拡張タグ）", :non_consolidated ]
  }.each do |doc_id, (name, consolidation_type)|
    it "#{name}: 費用のタグで左右を説明できないため、費用を差額で求めずに描かない" do
      _, chart = profit_loss(doc_id, consolidation_type)
      expect(chart.renderable).to be false
    end
  end
end
