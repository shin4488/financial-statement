require "rails_helper"

RSpec.describe Charts::Builders::PlJgaapBank do
  describe "経常黒字（実測値・単位: 円）" do
    let(:items) do
      { "pl.ordinary_revenue" => 14_620_843_000_000,
        "pl.ordinary_expenses" => 11_210_651_000_000,
        "pl.ordinary_profit" => 3_410_192_000_000 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方[経常費用, 経常利益] / 貸方[経常収益] で貸借一致する" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[ordinaryExpenses ordinaryProfit]
      expect(credit.segments.map(&:key)).to eq %w[ordinaryRevenue]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "経常損失" do
    let(:items) do
      { "pl.ordinary_revenue" => 1_000, "pl.ordinary_expenses" => 1_200,
        "pl.ordinary_profit" => -200 }
    end

    it "経常損失は貸方に積まれる" do
      debit, credit = described_class.new(items).build.bars
      expect(credit.segments.map(&:key)).to eq %w[ordinaryRevenue ordinaryLoss]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  it "経常収益・費用・利益のどれかが欠ければunrenderable" do
    expect(described_class.new({ "pl.ordinary_revenue" => 1, "pl.ordinary_expenses" => 1 }).build.renderable).to be false
  end
end
