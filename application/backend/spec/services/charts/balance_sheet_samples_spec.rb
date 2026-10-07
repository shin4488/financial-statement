require "rails_helper"

# 貸借対照表のグラフを、実XBRLの取込（公開API）から組み立てて確かめる。
# 期待値は有報の貸借対照表の金額で、棒の構成・名前・金額と、取込のときの照合の警告を見る
RSpec.describe "貸借対照表のグラフ（実XBRL）" do
  let(:warnings) { [] }

  before { allow(Sentry).to receive(:capture_message) { |message, **options| warnings << [ message, options ] } }

  def ingest(doc_id)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
  end

  def charts(doc_id, consolidation_type)
    ingest(doc_id)
    fs = Disclosure::FinancialStatement.find_by!(consolidation_type: consolidation_type)
    [ fs, Charts::BuilderRegistry.build_all(fs) ]
  end

  def segments(bar) = bar.segments.map { |segment| [ segment.label, segment.signed_amount ] }

  def balance_sheet_warnings = warnings.select { |message, _| message.start_with?("balance sheet") }

  describe "預金を企業拡張タグからも取る" do
    it "日本郵政 2026年3月期: 貯金を企業拡張タグから取り、銀行の様式で描く" do
      fs, charts = charts("S100YE7T", :consolidated)
      debit, credit = charts[:balance_sheet].bars
      aggregate_failures do
        expect(fs.presentation_format).to eq "jgaap_bank"
        expect(fs.items_hash["bs.deposits"]).to eq 184_652_065_000_000
        expect(segments(debit)).to eq [
          [ "現金預け金", 57_012_194_000_000 ], [ "貸出金", 6_434_130_000_000 ], [ "有価証券", 191_440_416_000_000 ],
          [ "その他資産", 289_864_524_000_000 - 57_012_194_000_000 - 6_434_130_000_000 - 191_440_416_000_000 ]
        ]
        expect(segments(credit)).to eq [
          [ "預金", 184_652_065_000_000 ], [ "その他負債", 273_382_599_000_000 - 184_652_065_000_000 ],
          [ "純資産", 16_481_925_000_000 ]
        ]
        expect(balance_sheet_warnings).to be_empty
      end
    end

    it "ゆうちょ銀行 2026年3月期: 連結・単体とも貯金を企業拡張タグから取り、描く" do
      ingest("S100Y9G1")
      aggregate_failures do
        { consolidated: 186_108_700_000_000, non_consolidated: 186_113_094_000_000 }.each do |type, deposits|
          fs = Disclosure::FinancialStatement.find_by!(consolidation_type: type)
          chart = Charts::BuilderRegistry.build_all(fs)[:balance_sheet]
          expect(chart.renderable).to be(true), "#{type}: #{chart.note}"
          expect(chart.bars.last.segments.first).to have_attributes(label: "預金", signed_amount: deposits)
        end
        expect(balance_sheet_warnings).to be_empty
      end
    end
  end

  it "ARCHION 2026年3月期: 資産0・債務超過の準備会社は、借方に何も積まず、負債を分母にして描く" do
    _, charts = charts("S100YK16", :non_consolidated)
    chart = charts[:balance_sheet]
    debit, credit, insolvency = chart.bars
    aggregate_failures do
      expect(chart.renderable).to be true
      expect(debit.segments).to be_empty
      expect(credit.segments.map { |s| [ s.label, s.signed_amount, s.ratio ] }).to eq [ [ "流動負債", 407_000_000, 100.0 ] ]
      expect(insolvency.label).to eq "債務超過"
      expect(insolvency.segments.map { |s| [ s.color_role, s.signed_amount, s.ratio ] })
        .to eq [ [ "spacer", 0, nil ], [ "equity", -407_000_000, -100.0 ] ]
      expect(balance_sheet_warnings).to be_empty
    end
  end

  it "ソニーフィナンシャルHD 2020年3月期: 銀行の経常収益がなく保険の経常収益があるため、保険の様式で描く" do
    fs, charts = charts("S100IXWZ", :consolidated)
    bs_debit, bs_credit = charts[:balance_sheet].bars
    pl_debit, pl_credit = charts[:profit_loss].bars
    aggregate_failures do
      expect(fs.presentation_format).to eq "jgaap_insurance"
      expect(segments(bs_credit).first).to eq [ "保険契約準備金", 10_731_488_000_000 ]
      expect(bs_debit.segments.sum(&:signed_amount)).to eq 15_125_710_000_000
      expect(segments(pl_debit)).to eq [ [ "経常費用", 1_669_540_000_000 ], [ "経常利益", 111_880_000_000 ] ]
      expect(segments(pl_credit)).to eq [ [ "経常収益", 1_781_420_000_000 ] ]
    end
  end

  it "ピクセラ 2025年9月期: 繰延資産を借方に積み、借方の合計が資産合計と端数の範囲で一致する" do
    _, charts = charts("S100XCO8", :consolidated)
    debit, = charts[:balance_sheet].bars
    aggregate_failures do
      expect(segments(debit)).to eq [
        [ "流動資産", 1_091_481_000 ], [ "有形固定資産", 0 ], [ "無形固定資産", 0 ],
        [ "投資その他資産", 23_664_000 ], [ "繰延資産", 11_276_000 ]
      ]
      expect(debit.segments.last.color_role).to eq "asset5"
      # 資産合計 1,126,422千円。差の1千円は各金額の千円未満の端数
      expect(debit.segments.sum(&:signed_amount)).to eq 1_126_421_000
      expect(balance_sheet_warnings).to be_empty
    end
  end

  it "三菱商事 2018年3月期: 2019年3月末より前に終わる年度のIFRSは、短い説明文を出す" do
    _, charts = charts("S100D97M", :consolidated)
    expect(charts[:balance_sheet]).to have_attributes(
      renderable: false, note: "財政状態計算書: 2019年3月末より前のIFRSは非対応です。")
  end

  it "いちよし証券 2025年3月期: 流動負債・固定負債のほかの負債（特別法上の準備金）は今のまま描かず、警告もしない" do
    _, charts = charts("S100Y87F", :consolidated)
    debit, credit = charts[:balance_sheet].bars
    aggregate_failures do
      expect(segments(debit)).to eq [ [ "流動資産", 35_927_000_000 ], [ "有形固定資産", 2_912_000_000 ],
                                      [ "無形固定資産", 750_000_000 ], [ "投資その他資産", 2_310_000_000 ] ]
      expect(segments(credit)).to eq [ [ "流動負債", 14_116_000_000 ], [ "固定負債", 118_000_000 ], [ "純資産", 27_461_000_000 ] ]
      expect(balance_sheet_warnings).to be_empty
    end
  end
end
