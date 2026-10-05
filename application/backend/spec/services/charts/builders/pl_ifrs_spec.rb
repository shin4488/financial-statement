require "rails_helper"

RSpec.describe Charts::Builders::PlIfrs do
  # 単位: 円
  describe "原価・販管費開示 + 税引前損失（その他損益が費用側）" do
    let(:items) do
      { "pl.revenue" => 4_505_720_000_000, "pl.cost_of_sales" => 1_571_588_000_000,
        "pl.sga" => 1_084_215_000_000, "pl.profit_before_tax" => -142_355_000_000 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方=原価+販管費+その他費用純額、貸方=収益+税引前損失になる" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga otherNet]
      expect(credit.segments.map(&:key)).to eq %w[revenue lossBeforeTax]
    end

    it "その他損益（純額）が残差を正確に埋める（貸借一致）" do
      debit, credit = chart.bars
      other = debit.segments.find { |s| s.key == "otherNet" }
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

  describe "その他損益が収益側（黒字・原価販管費開示）" do
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

    it "otherNetは収益と別の導出項目専用ロールになる" do
      _, credit = chart.bars
      other = credit.segments.find { |s| s.key == "otherNet" }
      expect(other.color_role).to eq "revenue2"
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

    it "その他損益（純額）は、収益・税引前利益・売上原価・販管費から決まる実際の差額になる" do
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
    def amounts(values)
      FinancialStatements::Amounts.new.tap do |amounts|
        values.each do |code, value|
          amounts[code] = value
          amounts.rounding_errors[code] = 1_000_000.to_d
        end
      end
    end

    let(:values) do
      { "pl.revenue" => 124_116_000_000, "pl.cost_of_sales" => -56_206_000_000, "pl.gross_profit" => 67_909_000_000,
        "pl.sga" => -56_931_000_000, "pl.profit_before_tax" => 18_069_000_000 }
    end

    it "収益−売上原価の絶対値が売上総利益と端数の範囲で一致すれば、費用を正の値として描き、左右が一致する" do
      debit, credit = described_class.new(amounts(values)).build.bars
      expect(debit.segments.map { |s| [ s.key, s.signed_amount ] })
        .to eq [ [ "costOfSales", 56_206_000_000 ], [ "sga", 56_931_000_000 ], [ "profitBeforeTax", 18_069_000_000 ] ]
      expect(credit.segments.map { |s| [ s.key, s.signed_amount ] })
        .to eq [ [ "revenue", 124_116_000_000 ], [ "otherNet", 7_090_000_000 ] ]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end

    it "売上総利益と一致しなければ、符号の付け間違いと確かめられないため描かない" do
      chart = described_class.new(amounts(values.merge("pl.gross_profit" => 60_000_000_000))).build
      expect(chart.renderable).to be false
      expect(chart.note).to include("表示に対応していません")
    end

    it "売上総利益がなければ確かめられないため描かない" do
      expect(described_class.new(amounts(values.except("pl.gross_profit"))).build.renderable).to be false
    end

    it "売上原価が正で販管費だけが負の値なら、確かめられないため描かない" do
      chart = described_class.new(amounts(values.merge("pl.cost_of_sales" => 56_206_000_000))).build
      expect(chart.renderable).to be false
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
