require "rails_helper"

RSpec.describe FinancialStatements::ItemCodes do
  it "コードが重複していない" do
    expect(described_class::ALL).to eq described_class::ALL.uniq
  end

  it "命名規則 <財務諸表>.<スネークケース英名> に従う" do
    expect(described_class::ALL).to all(match(/\A(bs|pl|cf)\.[a-z][a-z0-9_]*\z/))
  end

  it "プレフィクスと所属定数が一致している" do
    expect(described_class::BS).to all(start_with("bs."))
    expect(described_class::PL).to all(start_with("pl."))
    expect(described_class::CF).to all(start_with("cf."))
  end
end
