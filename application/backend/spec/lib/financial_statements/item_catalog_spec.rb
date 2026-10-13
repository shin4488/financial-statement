require "rails_helper"

RSpec.describe FinancialStatements::ItemCatalog do
  let(:items) { described_class::ITEMS }

  it "科目コードが重複していない" do
    expect(described_class::ALL).to eq described_class::ALL.uniq
  end

  it "命名規則 <財務諸表>.<スネークケース英名> に従う" do
    expect(described_class::ALL).to all(match(/\A(bs|pl|cf)\.[a-z][a-z0-9_]*\z/))
  end

  it "すべての科目に、時点か期間かと意味がある" do
    expect(items).to all(have_attributes(period: :instant).or(have_attributes(period: :duration)))
    expect(items.map(&:description)).to all(be_present)
  end

  describe "期首の科目" do
    it "同じ財務諸表の、期首の科目でない時点の科目の前期末を指す" do
      items.select(&:opening?).each do |item|
        closing = items.find { |candidate| candidate.code == item.opening_of }
        expect(closing).to have_attributes(period: :instant, opening?: false)
        expect(item.period).to eq :instant
        expect(item.code.split(".").first).to eq closing.code.split(".").first
      end
    end

    it "1つの科目の期首は1つだけ" do
      closings = items.select(&:opening?).map(&:opening_of)
      expect(closings).to eq closings.uniq
    end

    it ".opening_codes は期首の科目だけを返す" do
      expect(described_class.opening_codes).to eq %w[bs.assets_begin bs.equity_attributable_to_owners_begin cf.cash_begin]
    end
  end
end
