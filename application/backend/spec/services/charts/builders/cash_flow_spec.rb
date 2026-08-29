require "rails_helper"

RSpec.describe Charts::Builders::CashFlow do
  let(:items) do
    { "cf.cash_begin" => 109_095_437, "cf.operating" => -23_064_420,
      "cf.investing" => 4_473_959, "cf.financing" => -1_149_876,
      "cf.cash_end" => 90_045_500 }
  end

  it "5ステップがkind付き・符号付きで返る（単位: 百万円）" do
    chart = described_class.new(items).build
    expect(chart.renderable).to be true
    expect(chart.steps.map(&:key)).to eq %w[cashBegin operating investing financing cashEnd]
    expect(chart.steps.map(&:kind)).to eq %w[balance flow flow flow balance]
    expect(chart.steps[1].amount).to eq(-23_064_420) # 符号は保持される
  end

  it "色の役割は増減の向きで決まる（負=cashDecrease。符号の解釈をフロントにさせない）" do
    chart = described_class.new(items).build
    expect(chart.steps.map(&:color_role))
      .to eq %w[cashIncrease cashDecrease cashIncrease cashDecrease cashIncrease]
  end

  it "1点でも欠けるとunrenderable（滝の繋がりが崩れるため）" do
    chart = described_class.new(items.except("cf.cash_begin")).build
    expect(chart.renderable).to be false
    expect(chart.steps).to be_empty
  end
end
