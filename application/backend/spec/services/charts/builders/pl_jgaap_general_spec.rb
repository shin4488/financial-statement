require "rails_helper"

RSpec.describe Charts::Builders::PlJgaapGeneral do
  describe "黒字" do
    let(:items) do
      { "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 300,
        "pl.operating_profit" => 100 }
    end
    subject(:chart) { described_class.new(items).build }

    it "借方[原価, 販管費, 営業利益] / 貸方[売上] になる" do
      debit, credit = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga operatingProfit]
      expect(credit.segments.map(&:key)).to eq %w[revenue]
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "営業損失" do
    let(:items) do
      { "pl.revenue" => 1_000, "pl.cost_of_sales" => 800, "pl.sga" => 400,
        "pl.operating_profit" => -200 }
    end
    subject(:chart) { described_class.new(items).build }

    it "営業損失は貸方に符号付き実値で積まれる" do
      debit, credit = chart.bars
      loss = credit.segments.find { |s| s.key == "operatingLoss" }
      expect(loss.amount).to eq 200
      expect(loss.signed_amount).to eq(-200)
      expect(debit.segments.sum(&:amount)).to eq credit.segments.sum(&:amount)
    end
  end

  describe "原価・販管費がない持株会社型" do
    it "売上と営業利益だけで描画される（nilは0扱い）" do
      chart = described_class.new({ "pl.revenue" => 1_000, "pl.operating_profit" => 1_000 }).build
      expect(chart.renderable).to be true
      debit, = chart.bars
      expect(debit.segments.map(&:key)).to eq %w[costOfSales sga operatingProfit]
      expect(debit.segments.map(&:amount)).to eq [0, 0, 1_000]
    end
  end

  it "売上か営業利益が欠ければunrenderable" do
    expect(described_class.new({ "pl.operating_profit" => 100 }).build.renderable).to be false
    expect(described_class.new({ "pl.revenue" => 100 }).build.renderable).to be false
    expect(described_class.new({ "pl.revenue" => 0, "pl.operating_profit" => 1 }).build.renderable).to be false
  end
end
