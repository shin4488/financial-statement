require "rails_helper"

RSpec.describe Charts::Builders::PlIfrs do
  let(:items) do
    { "pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 200,
     "pl.finance_income" => 20, "pl.finance_costs" => 50,
     "pl.equity_method_profit" => -10, "pl.profit_before_tax" => 160 }
  end

  it "開示された金融損益・持分法損益を積み上げて税引前利益に一致する" do
    chart = described_class.new(items).build
    expect(chart.renderable).to be true
    debit, credit = chart.bars
    expect(debit.segments.sum(&:amount)).to eq 1_020
    expect(credit.segments.sum(&:amount)).to eq 1_020
    expect(debit.segments.find { |s| s.key == "equityMethod" }.signed_amount).to eq(-10)
    expect((debit.segments + credit.segments).map(&:key)).not_to include("otherNet")
  end

  it "営業費用合計が内訳と併記されても二重に加算しない" do
    chart = described_class.new(items.merge("pl.operating_expenses" => 800)).build
    expect(chart.bars.first.segments.map(&:key)).to include("costOfSales", "sga")
    expect(chart.bars.first.segments.map(&:key)).not_to include("operatingExpenses")
  end

  it "費用合計だけの開示も税引前利益まで検算する" do
    chart = described_class.new(items.except("pl.cost_of_sales", "pl.sga").merge("pl.operating_expenses" => 800)).build
    expect(chart.renderable).to be true
    expect(chart.bars.first.segments.first.key).to eq "operatingExpenses"
  end

  it "費用欠損や不整合をその他損益という差額で埋めない" do
    [ items.except("pl.finance_costs"), items.merge("pl.profit_before_tax" => 150),
     { "pl.revenue" => 1_000, "pl.profit_before_tax" => 160 } ].each do |input|
      chart = described_class.new(input).build
      expect(chart.renderable).to be false
      expect(chart.bars).to be_empty
      expect(chart.note).to include("関係を確認できない")
    end
  end

  it "税引前損失の符号と比率を保持する" do
    chart = described_class.new(items.merge("pl.finance_costs" => 250, "pl.profit_before_tax" => -40)).build
    loss = chart.bars.last.segments.last
    expect(loss.key).to eq "lossBeforeTax"
    expect(loss.signed_amount).to eq(-40)
    expect(loss.ratio).to eq(-4)
  end
end
