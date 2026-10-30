require "rails_helper"

RSpec.describe Charts::Tolerance do
  describe ".within?" do
    it "分母の1割ちょうどのずれは許容し、超えれば許容しない" do
      aggregate_failures do
        expect(described_class.within?(1_000, 1_100)).to be true
        expect(described_class.within?(1_000, 900)).to be true
        expect(described_class.within?(1_000, 1_101)).to be false
        expect(described_class.within?(1_000, 899)).to be false
      end
    end

    it "分母が0なら、値が0でも許容しない" do
      expect(described_class.within?(0, 0)).to be false
    end
  end

  describe ".balanced?" do
    def amounts(rounding_errors)
      FinancialStatements::Amounts.new.tap do |amounts|
        rounding_errors.each { |code, error| amounts.store(code, 1_000, error) }
      end
    end

    it "差の絶対値が、式に使った金額の端数の合計未満なら一致とみなす" do
      items = amounts("a" => 1.to_d, "b" => 1.to_d, "c" => 100.to_d)
      aggregate_failures do
        expect(described_class.balanced?(items, 1, %w[a b])).to be true
        expect(described_class.balanced?(items, -1, %w[a b])).to be true
        expect(described_class.balanced?(items, 2, %w[a b])).to be false # 式に使っていない c の端数は数えない
      end
    end

    it "式に使った金額のどれかの精度が分からなければ、差が0のときだけ一致とみなす" do
      items = amounts("a" => 1.to_d, "b" => nil)
      expect(described_class.balanced?(items, 0, %w[a b])).to be true
      expect(described_class.balanced?(items, 1, %w[a b])).to be false
    end

    it "精度の分からない金額を含めば、ほかの金額の端数の合計より小さい差でも一致とみなさない" do
      items = amounts("a" => 2.to_d, "b" => nil)
      expect(described_class.balanced?(items, 1, %w[a b])).to be false
    end
  end
end
