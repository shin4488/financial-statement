require "rails_helper"

RSpec.describe FinancialStatements::RoundingRange do
  it "差が0なら、精度によらず一致とする" do
    expect(described_class.within?(0, [ 1_000_000.to_d, nil ])).to be true
  end

  it "差が、式に使った金額の端数の合計未満なら一致とする" do
    # 百万円単位の3つの金額（売上・売上原価・売上総利益）から計算した差1百万円
    expect(described_class.within?(1_000_000, [ 1_000_000.to_d ] * 3)).to be true
    expect(described_class.within?(-2_999_999, [ 1_000_000.to_d ] * 3)).to be true
  end

  it "差が端数の合計に達するなら一致としない" do
    expect(described_class.within?(3_000_000, [ 1_000_000.to_d ] * 3)).to be false
  end

  it "差があり、精度の分からない金額を含むときは一致としない" do
    expect(described_class.within?(1, [ 1_000_000.to_d, nil ])).to be false
  end
end
