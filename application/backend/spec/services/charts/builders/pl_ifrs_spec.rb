require "rails_helper"

RSpec.describe Charts::Builders::PlIfrs do
  # 実XBRLからの実測値をそのまま期待値に使う（単位: 円）
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

  describe "収益が取得できない（保険IFRS等）" do
    it "unrenderableになりnoteが入る" do
      chart = described_class.new({ "pl.profit_before_tax" => 750_700_000_000 }).build
      expect(chart.renderable).to be false
      expect(chart.note).to include("表示に対応していません")
      expect(chart.bars).to be_empty
    end
  end
end
