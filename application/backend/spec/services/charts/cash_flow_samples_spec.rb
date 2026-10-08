require "rails_helper"

# キャッシュ・フロー計算書のグラフを、実XBRLの取込（公開API）から組み立てて確かめる。
# 期待値は有報のCF計算書の金額で、5点の値と、FCF推移・取込のときの照合の警告を見る
RSpec.describe "キャッシュ・フロー計算書のグラフ（実XBRL）" do
  let(:warnings) { [] }

  before { allow(Sentry).to receive(:capture_message) { |message, **options| warnings << [ message, options ] } }

  def cash_flow(doc_id, consolidation_type)
    require_xbrl_fixture(doc_id)
    Dir.mktmpdir do |work_dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: work_dir)
    end
    fs = Disclosure::FinancialStatement.find_by!(consolidation_type: consolidation_type)
    [ fs, Charts::BuilderRegistry.build_all(fs)[:cash_flow] ]
  end

  def steps(chart) = chart.steps.to_h { |step| [ step.key, step.amount ] }

  def cash_flow_warnings = warnings.select { |message, _| message.start_with?("cash flow") }

  describe "活動がなく「－」の項目を0として扱う" do
    it "ぷらっとホーム 2021年3月期: 財務CFの行がなく、換算差額を含めた式が端数の範囲で成り立つため、財務CFを0として描く" do
      fs, chart = cash_flow("S100LR17", :non_consolidated)
      aggregate_failures do
        expect(fs.items_hash).not_to have_key("cf.financing") # 保存する値は変えない
        expect(steps(chart)).to eq("cashBegin" => 334_170_000, "operating" => -12_047_000, "investing" => -3_400_000,
                                   "financing" => 0, "cashEnd" => 318_777_000)
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "キャンバス 2026年6月期: 投資CF・財務CFが「－」で、FCF推移も投資CFを0として営業CFだけになる" do
      fs, chart = cash_flow("S100Z4G9", :non_consolidated)
      trend = FinancialStatements::FreeCashFlowTrends.build([ fs.report ]).fetch(fs.report.id)
      aggregate_failures do
        expect(steps(chart)).to eq("cashBegin" => 2_827_879_000, "operating" => -1_424_017_000, "investing" => 0,
                                   "financing" => 0, "cashEnd" => 1_445_095_000)
        expect(trend.points.last).to have_attributes(operating_cf: -1_424_017_000, investing_cf: 0, amount: -1_424_017_000)
      end
    end

    it "visumo 2026年3月期: 合併による増加（23,354千円）を式に含めて、財務CFを0として描く" do
      fs, chart = cash_flow("S100YCOW", :non_consolidated)
      aggregate_failures do
        expect(fs.items_hash["cf.merger"]).to eq 23_354_000
        expect(steps(chart)["financing"]).to eq 0
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "リプロセル 2026年3月期: 換算差額（105,922千円）を式に含めて、財務CFを0として描く" do
      _, chart = cash_flow("S100YLVF", :consolidated)
      expect(steps(chart)).to eq("cashBegin" => 2_823_367_000, "operating" => -383_526_000, "investing" => 57_940_000,
                                 "financing" => 0, "cashEnd" => 2_603_703_000)
    end

    it "関西みらいフィナンシャルグループ 2018年3月期: 新設会社の期首残を0として描く" do
      _, chart = cash_flow("S100DGXR", :consolidated)
      expect(steps(chart)).to eq("cashBegin" => 0, "operating" => -89_683_000_000, "investing" => 343_140_000_000,
                                 "financing" => 49_179_000_000, "cashEnd" => 302_636_000_000)
    end

    it "ARCHION 2026年3月期: 現金の出入りがない準備会社は、期首残・営業CF・投資CFを0として描く" do
      _, chart = cash_flow("S100YK16", :non_consolidated)
      expect(steps(chart).values).to eq [ 0, 0, 0, 0, 0 ]
    end

    it "窪田製薬ホールディングス 2015年12月期: 設立から間もなく、資本金の払込み（財務CF500千円）だけの会社を描く" do
      _, chart = cash_flow("S1009DYN", :non_consolidated)
      expect(steps(chart)).to eq("cashBegin" => 0, "operating" => 0, "investing" => 0,
                                 "financing" => 500_000, "cashEnd" => 500_000)
    end

    it "クックビズ 2022年11月期: 連結初年度で連結CFを作っていない連結は、期末残もないため0として描かず、警告もしない" do
      _, chart = cash_flow("S100QBCW", :consolidated)
      aggregate_failures do
        expect(chart.renderable).to be false
        expect(cash_flow_warnings).to be_empty
      end
    end
  end

  it "Fringe81 2017年3月期: CF計算書の期末残に標準タグがなく、経営指標の要約の現金同等物の残高で補う" do
    fs, chart = cash_flow("S100AQXU", :non_consolidated)
    aggregate_failures do
      expect(fs.items_hash["cf.cash_end"]).to eq 275_119_000
      # 527,442−53,651−321,582＋122,911＝275,120千円。差の1千円は各金額の千円未満の端数
      expect(steps(chart)).to eq("cashBegin" => 527_442_000, "operating" => -53_651_000, "investing" => -321_582_000,
                                 "financing" => 122_911_000, "cashEnd" => 275_119_000)
      expect(cash_flow_warnings).to be_empty
    end
  end

  describe "IFRSの期首残・期末残は、CF計算書の残高で描く" do
    it "THK 2025年12月期: CF計算書の期末残（120,534百万円）が財政状態計算書の現金及び現金同等物（110,008百万円）と違い、CF計算書の残高で描く" do
      fs, chart = cash_flow("S100XRWN", :consolidated)
      aggregate_failures do
        expect(steps(chart)).to include("cashBegin" => 138_293_000_000, "cashEnd" => 120_534_000_000)
        expect(fs.items_hash["bs.cash_and_equivalents"]).to eq 110_008_000_000 # BSの科目は財政状態計算書の額のまま
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "富士通 2026年3月期: CF計算書の期首残（320,099百万円）が前期末の財政状態計算書の額と違い、CF計算書の残高で描く" do
      _, chart = cash_flow("S100YM3K", :consolidated)
      aggregate_failures do
        expect(steps(chart)).to include("cashBegin" => 320_099_000_000, "cashEnd" => 450_366_000_000)
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "第一三共 2026年3月期: 売却目的で保有する資産への振替の前のCF計算書の期末残（488,983百万円）で式が成り立ち、その額で描く" do
      _, chart = cash_flow("S100YZB3", :consolidated)
      aggregate_failures do
        expect(steps(chart)).to include("cashBegin" => 639_838_000_000, "cashEnd" => 488_983_000_000)
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "兼松 2026年3月期: CF計算書用のタグを調整後の期首残高の行に付けていて式が成り立たないため、財政状態計算書の額のまま描いて警告する" do
      _, chart = cash_flow("S100YGCZ", :consolidated)
      aggregate_failures do
        expect(steps(chart)).to include("cashBegin" => 56_779_000_000, "cashEnd" => 58_418_000_000)
        expect(cash_flow_warnings.map(&:first)).to eq [ "cash flow does not reconcile with closing balance" ]
      end
    end

    it "武田薬品工業 2026年3月期: CF計算書の残高を別に開示していない会社は、財政状態計算書の現金及び現金同等物で描く" do
      _, chart = cash_flow("S100YB5L", :consolidated)
      aggregate_failures do
        expect(steps(chart)).to include("cashBegin" => 385_113_000_000, "cashEnd" => 595_054_000_000)
        expect(cash_flow_warnings).to be_empty
      end
    end
  end

  describe "日本基準の連結範囲の変更・合併の行は、標準タグの分け方によらず式に含める" do
    it "良品計画 2025年8月期: 連結除外に伴う現金及び現金同等物の減少額（△175百万円）を含めて式が成り立つ" do
      fs = cash_flow("S100X5NI", :consolidated).first
      aggregate_failures do
        expect(fs.items_hash["cf.consolidation_change"]).to eq(-175_000_000)
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "コシダカホールディングス 2023年8月期: 非連結子会社との合併に伴う現金及び現金同等物の増加額（13,878千円）を含めて式が成り立つ" do
      fs = cash_flow("S100X7D9", :consolidated).first
      aggregate_failures do
        expect(fs.items_hash["cf.merger"]).to eq 13_878_000
        expect(cash_flow_warnings).to be_empty
      end
    end

    it "前澤給装工業 2026年3月期: 連結子会社の合併による現金及び現金同等物の増減額（289百万円）を含めて式が成り立つ" do
      fs = cash_flow("S100YIVJ", :non_consolidated).first
      aggregate_failures do
        expect(fs.items_hash["cf.merger"]).to eq 289_000_000
        expect(cash_flow_warnings).to be_empty
      end
    end
  end

  it "新都ホールディングス 2026年1月期: 5点がそろって描くが、式に入れていない行があり式が合わないため警告する" do
    _, chart = cash_flow("S100YXHA", :consolidated)
    aggregate_failures do
      expect(chart.renderable).to be true
      expect(cash_flow_warnings.map(&:first)).to eq [ "cash flow does not reconcile with closing balance" ]
      expect(cash_flow_warnings.dig(0, 1, :extra, :amounts)).to include("cf.cash_begin" => 203_615_000, "cf.cash_end" => 913_804_000)
    end
  end
end
