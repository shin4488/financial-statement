require "rails_helper"

RSpec.describe Charts::Builders::PlIfrs do
  # 金額に、表示単位（百万円・千円）から決まる端数を持たせる
  def amounts(values, rounding_error)
    FinancialStatements::Amounts.new.tap do |amounts|
      values.each do |code, value|
        amounts[code] = value
        amounts.rounding_errors[code] = rounding_error.to_d
      end
    end
  end

  def labeled(bar) = bar.segments.map { |s| [ s.label, s.signed_amount ] }

  # 単位: 円
  describe "原価・販管費開示 + 税引前損失（差額が費用側）" do
    let(:items) do
      { "pl.revenue" => 4_505_720_000_000, "pl.cost_of_sales" => 1_571_588_000_000,
        "pl.sga" => 1_084_215_000_000, "pl.profit_before_tax" => -142_355_000_000 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方=原価+販管費+差額、貸方=収益+税引前損失になる" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga otherNet]
      expect(credit.segments.map(&:key)).to eq %w[revenue lossBeforeTax]
    end

    it "差額は「その他の費用（純額）」として残差を正確に埋める（貸借一致）" do
      debit, credit = chart.bars
      other = debit.segments.find { |s| s.key == "otherNet" }
      expect(other.label).to eq "その他の費用（純額）"
      expect(other.amount).to eq 1_992_272_000_000           # 描画高さは絶対値
      expect(other.signed_amount).to eq(-1_992_272_000_000)  # 実値は負
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end

    it "損失セグメントのratioは負になる" do
      _, credit = chart.bars
      loss = credit.segments.find { |s| s.key == "lossBeforeTax" }
      expect(loss.ratio).to be < 0
    end
  end

  describe "差額が収益側（黒字・原価販管費開示）" do
    let(:items) do
      { "pl.revenue" => 18_915_995_000_000, "pl.cost_of_sales" => 16_386_035_000_000,
        "pl.sga" => 2_218_395_000_000, "pl.profit_before_tax" => 1_096_094_000_000 }
    end
    subject(:chart) { described_class.new(items).build }

    it "貸方にotherNet、借方に税引前利益が積まれ貸借一致する" do
      debit, credit = chart.bars
      expect(credit.segments.map(&:key)).to include("otherNet")
      expect(debit.segments.map(&:key)).to include("profitBeforeTax")
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end

    it "差額は「その他の収益（純額）」として、収益と別の差額専用ロールになる" do
      _, credit = chart.bars
      other = credit.segments.find { |s| s.key == "otherNet" }
      expect([ other.label, other.color_role ]).to eq [ "その他の収益（純額）", "revenue2" ]
    end
  end

  describe "営業費用一括型 + 税引前損失" do
    let(:items) do
      { "pl.revenue" => 2_496_575_000_000, "pl.operating_expenses" => 2_395_113_000_000,
        "pl.profit_before_tax" => -29_550_000_000 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方はoperatingExpensesで始まり貸借一致する" do
      debit, credit = chart.bars
      expect(debit.segments.first.key).to eq "operatingExpenses"
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "営業費用を売上原価・販管費の合計として併記する" do
    # KDDI 2025年3月期: 営業費用4,773,120百万円 = 売上原価3,343,655 + 販管費1,429,465
    let(:items) do
      { "pl.revenue" => 5_835_525_000_000, "pl.cost_of_sales" => 3_343_655_000_000,
        "pl.sga" => 1_429_465_000_000, "pl.operating_expenses" => 4_773_120_000_000,
        "pl.profit_before_tax" => 1_073_418_000_000 }
    end
    subject(:chart) { described_class.new(items).build }

    it "営業費用は積まず、費用を二重に数えない" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga profitBeforeTax]
      expect(credit.segments.map(&:key)).to eq %w[revenue otherNet]
    end

    it "差額は、収益・税引前利益・売上原価・販管費から決まる実際の差額になる" do
      _, credit = chart.bars
      expect(credit.segments.find { |s| s.key == "otherNet" }.signed_amount).to eq 11_013_000_000
    end

    it "営業費用が合計と符号だけ逆に付いていても積まない" do
      chart = described_class.new(items.merge("pl.operating_expenses" => -4_773_120_000_000)).build
      expect(chart.bars.first.segments.map(&:key)).to eq %w[costOfSales sga profitBeforeTax]
    end
  end

  describe "費用を負の値でタグ付けしている" do
    # ディー・エヌ・エー 2019年3月期（百万円単位で開示）
    let(:values) do
      { "pl.revenue" => 124_116_000_000, "pl.cost_of_sales" => -56_206_000_000, "pl.gross_profit" => 67_909_000_000,
        "pl.sga" => -56_931_000_000, "pl.profit_before_tax" => 18_069_000_000 }
    end

    it "収益−売上原価の絶対値が売上総利益と端数の範囲で一致すれば、費用を正の値として描き、左右が一致する" do
      debit, credit = described_class.new(amounts(values, 1_000_000)).build.bars
      expect(debit.segments.map { |s| [ s.key, s.signed_amount ] })
        .to eq [ [ "costOfSales", 56_206_000_000 ], [ "sga", 56_931_000_000 ], [ "profitBeforeTax", 18_069_000_000 ] ]
      expect(credit.segments.map { |s| [ s.key, s.signed_amount ] })
        .to eq [ [ "revenue", 124_116_000_000 ], [ "otherNet", 7_090_000_000 ] ]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end

    it "売上総利益と一致しなければ、符号の付け間違いと確かめられないため描かない" do
      chart = described_class.new(amounts(values.merge("pl.gross_profit" => 60_000_000_000), 1_000_000)).build
      expect(chart.renderable).to be false
      expect(chart.note).to include("表示に対応していません")
    end

    it "売上総利益がなければ確かめられないため描かない" do
      expect(described_class.new(amounts(values.except("pl.gross_profit"), 1_000_000)).build.renderable).to be false
    end

    it "売上原価が正で販管費だけが負の値なら、確かめられないため描かない" do
      chart = described_class.new(amounts(values.merge("pl.cost_of_sales" => 56_206_000_000), 1_000_000)).build
      expect(chart.renderable).to be false
    end
  end

  describe "表示した費用がない（売上原価・販管費・営業費用のタグがない）" do
    it "差額が費用側なら、通常の費用がすべて入るため「費用（純額）」になる" do
      # HOYA 2026年3月期
      debit, credit = described_class.new({ "pl.revenue" => 947_749_000_000, "pl.profit_before_tax" => 327_668_000_000 }).build.bars
      aggregate_failures do
        expect(labeled(debit)).to eq [ [ "費用（純額）", -620_081_000_000 ], [ "税引前利益", 327_668_000_000 ] ]
        expect(labeled(credit)).to eq [ [ "収益", 947_749_000_000 ] ]
      end
    end

    it "税引前利益が収益より大きく、差額が収益側なら「その他の収益（純額）」になる" do
      debit, credit = described_class.new({ "pl.revenue" => 100, "pl.profit_before_tax" => 130 }).build.bars
      aggregate_failures do
        expect(labeled(debit)).to eq [ [ "税引前利益", 130 ] ]
        expect(labeled(credit)).to eq [ [ "収益", 100 ], [ "その他の収益（純額）", 30 ] ]
      end
    end
  end

  describe "売上0" do
    # 窪田製薬ホールディングス 2019年12月期（千円単位で開示）
    let(:values) do
      { "pl.revenue" => 0, "pl.research_and_development" => 2_756_331_000,
        "pl.general_and_administrative_expenses" => 532_076_000, "pl.operating_profit" => -3_288_407_000,
        "pl.profit_before_tax" => -3_105_243_000 }
    end

    it "費用の合計が営業損失と一致すれば、借方に費用、貸方に営業損失を積み、比率の分母を営業損失にする" do
      debit, credit = described_class.new(amounts(values, 1_000)).build.bars
      aggregate_failures do
        expect(debit.segments.map { |s| [ s.label, s.signed_amount, s.ratio ] })
          .to eq [ [ "研究開発費", 2_756_331_000, 83.8 ], [ "一般管理費", 532_076_000, 16.1 ] ]
        expect(credit.segments.map { |s| [ s.label, s.signed_amount, s.ratio ] }).to eq [ [ "営業損失", -3_288_407_000, -100.0 ] ]
        expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
      end
    end

    it "費用の合計と営業損失の差が端数の範囲なら、一致とみなして描く" do
      chart = described_class.new(amounts(values.merge("pl.general_and_administrative_expenses" => 532_075_000), 1_000)).build
      expect(chart.renderable).to be true
    end

    it "営業損失にその他の営業収益が含まれ、費用の合計と一致しなければ、費用を差額で求めずに描かない" do
      # 窪田製薬ホールディングス 2021年12月期: 研究開発費・一般管理費の合計2,644,579千円、営業損失2,584,705千円
      kubota2021 = { "pl.revenue" => 0, "pl.research_and_development" => 2_040_674_000,
                     "pl.general_and_administrative_expenses" => 603_905_000, "pl.operating_profit" => -2_584_705_000,
                     "pl.profit_before_tax" => -2_616_451_000 }
      expect(described_class.new(amounts(kubota2021, 1_000)).build.renderable).to be false
    end

    it "内訳の科目がなければ、営業費用と営業損失で描く" do
      chart = described_class.new({ "pl.revenue" => 0, "pl.operating_expenses" => 500, "pl.operating_profit" => -500 }).build
      expect(chart.bars.map { |bar| labeled(bar) }).to eq [ [ [ "営業費用", 500 ] ], [ [ "営業損失", -500 ] ] ]
    end

    it "営業損失がなければ描かない" do
      aggregate_failures do
        expect(described_class.new(values.except("pl.operating_profit")).build.renderable).to be false
        expect(described_class.new(values.merge("pl.operating_profit" => 3_288_407_000)).build.renderable).to be false
      end
    end

    it "費用のタグが負の値なら、符号の付け間違いを確かめられないため描かない" do
      chart = described_class.new(values.merge("pl.research_and_development" => -2_756_331_000,
                                               "pl.general_and_administrative_expenses" => 6_044_738_000)).build
      expect(chart.renderable).to be false
    end
  end

  describe "照合（取込のときにSentryへ警告する金額）" do
    # KDDI 2025年3月期: 営業費用4,773,120百万円 = 売上原価3,343,655 + 販管費1,429,465
    let(:values) do
      { "pl.revenue" => 5_835_525_000_000, "pl.cost_of_sales" => 3_343_655_000_000,
        "pl.sga" => 1_429_465_000_000, "pl.operating_expenses" => 4_773_120_000_000,
        "pl.profit_before_tax" => 1_073_418_000_000 }
    end

    it "積まなかった営業費用が売上原価・販管費の合計と一致すれば（符号だけが逆でも）、警告しない" do
      aggregate_failures do
        expect(described_class.new(values).mismatch).to be_nil
        expect(described_class.new(values.merge("pl.operating_expenses" => -4_773_120_000_000)).mismatch).to be_nil
      end
    end

    it "差が端数の範囲なら一致とみなし、警告しない" do
      expect(described_class.new(amounts(values.merge("pl.operating_expenses" => 4_773_121_000_000), 1_000_000)).mismatch).to be_nil
    end

    it "積まなかった営業費用が売上原価・販管費の合計と一致しなければ、照合に使った金額を返す" do
      # トヨタ自動車 2026年3月期: 営業費用の合計に、売上原価・販管費のほかの費用の行が入っている
      toyota = { "pl.revenue" => 50_684_952_000_000, "pl.cost_of_sales" => 39_141_418_000_000,
                 "pl.sga" => 4_697_524_000_000, "pl.operating_expenses" => 46_918_736_000_000,
                 "pl.profit_before_tax" => 5_152_996_000_000 }
      expect(described_class.new(amounts(toyota, 1_000_000)).mismatch).to eq(
        "pl.cost_of_sales" => 39_141_418_000_000, "pl.sga" => 4_697_524_000_000, "pl.operating_expenses" => 46_918_736_000_000)
    end

    it "販管費と営業費用が別の行なら、販管費と営業費用の金額を返す" do
      # Jトラスト 2020年12月期
      jtrust = { "pl.revenue" => 32_652_000_000, "pl.sga" => 19_643_000_000, "pl.operating_expenses" => 17_653_000_000,
                 "pl.profit_before_tax" => -2_978_000_000 }
      expect(described_class.new(jtrust).mismatch).to eq("pl.sga" => 19_643_000_000, "pl.operating_expenses" => 17_653_000_000)
    end

    it "営業費用を積むとき（内訳がない）と、表示した費用がないとき（要約形式など）は、照合する式がないため警告しない" do
      aggregate_failures do
        expect(described_class.new(values.except("pl.cost_of_sales", "pl.sga")).mismatch).to be_nil
        expect(described_class.new(values.slice("pl.revenue", "pl.profit_before_tax")).mismatch).to be_nil
      end
    end

    it "描かないPL（売上0、収益か税引前利益がない）は照合しない" do
      mismatched = values.merge("pl.operating_expenses" => 1)
      aggregate_failures do
        expect(described_class.new(mismatched.except("pl.revenue")).mismatch).to be_nil
        expect(described_class.new(mismatched.except("pl.profit_before_tax")).mismatch).to be_nil
        expect(described_class.new(mismatched.merge("pl.revenue" => 0)).mismatch).to be_nil
      end
    end
  end

  describe "収益が取得できない（保険IFRS等）" do
    it "unrenderableになりnoteが入る" do
      chart = described_class.new({ "pl.profit_before_tax" => 750_700_000_000 }).build
      expect(chart.renderable).to be false
      expect(chart.note).to include("表示に対応していません")
      expect(chart.bars).to be_empty
    end
  end
end
