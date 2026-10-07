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

  it "1点でも欠け、0とみなしてもCFの式が成り立たなければunrenderable（滝の繋がりが崩れるため）" do
    chart = described_class.new(items.except("cf.cash_begin")).build
    expect(chart.renderable).to be false
    expect(chart.steps).to be_empty
  end

  it "活動がなく行がない項目は、0とみなしてCFの式が成り立てば0として描く" do
    chart = described_class.new(items.merge("cf.financing" => nil, "cf.cash_end" => 90_504_976).compact).build
    aggregate_failures do
      expect(chart.renderable).to be true
      expect(chart.steps.map { |step| [ step.key, step.amount ] }).to eq [
        [ "cashBegin", 109_095_437 ], [ "operating", -23_064_420 ], [ "investing", 4_473_959 ],
        [ "financing", 0 ], [ "cashEnd", 90_504_976 ]
      ]
      expect(chart.steps[3].color_role).to eq "cashIncrease"
    end
  end

  describe "#mismatch（取込のときの照合）" do
    it "5点がそろっていても、換算差額などを含めた式が成り立たなければ金額を返す" do
      expect(described_class.new(items).mismatch).to eq items
    end

    it "換算差額を含めて式が成り立てばnil" do
      expect(described_class.new(items.merge("cf.exchange_effect" => 690_400)).mismatch).to be_nil
    end
  end
end
