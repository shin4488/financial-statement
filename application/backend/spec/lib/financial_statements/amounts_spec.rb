require "rails_helper"

RSpec.describe FinancialStatements::Amounts do
  # 百万円単位で開示した資産合計と、精度の分からない売上
  def sample
    described_class.new.tap do |amounts|
      amounts["bs.assets"] = 100_000_000
      amounts.rounding_errors["bs.assets"] = 1_000_000.to_d
      amounts["pl.revenue"] = 50_000_000
      amounts.rounding_errors["pl.revenue"] = nil
    end
  end

  describe "#store" do
    it "金額と端数の上限を組で書き、金額を返す" do
      amounts = described_class.new
      expect(amounts.store("bs.assets", 100_000_000, 1_000_000.to_d)).to eq 100_000_000
      expect(amounts).to eq("bs.assets" => 100_000_000)
      expect(amounts.rounding_errors).to eq("bs.assets" => 1_000_000.to_d)
    end

    it "精度の分からない端数（nil）も、科目のキーを作って書く" do
      amounts = described_class.new
      amounts.store("pl.revenue", 50_000_000, nil)
      expect(amounts.rounding_errors).to have_key("pl.revenue")
      expect(amounts.rounding_errors["pl.revenue"]).to be_nil
    end

    it "端数を省くと、Hashのstoreと同じく金額だけを書き、端数の表は変えない" do
      amounts = sample
      expect(amounts.store("bs.assets", 200_000_000)).to eq 200_000_000
      expect(amounts).to eq("bs.assets" => 200_000_000, "pl.revenue" => 50_000_000)
      expect(amounts.rounding_errors).to eq("bs.assets" => 1_000_000.to_d, "pl.revenue" => nil)
    end

    it "[]= は今と同じく金額だけを書く" do
      amounts = sample
      amounts["cf.cash_end"] = 10_000_000
      expect(amounts["cf.cash_end"]).to eq 10_000_000
      expect(amounts.rounding_errors).not_to have_key("cf.cash_end")
    end
  end

  describe "#same_values?" do
    it "金額が同じなら、端数が違っても真" do
      other = sample.tap { |amounts| amounts.rounding_errors["bs.assets"] = 1_000.to_d }
      expect(sample.same_values?(other)).to be true
    end

    it "金額が違えば偽" do
      other = sample.tap { |amounts| amounts["bs.assets"] = 100_000_001 }
      expect(sample.same_values?(other)).to be false
    end

    it "片方にしかない科目があれば偽" do
      other = sample.tap { |amounts| amounts["cf.cash_end"] = 10_000_000 }
      expect(sample.same_values?(other)).to be false
      expect(other.same_values?(sample)).to be false
    end
  end

  describe "#==" do
    it "今と同じく金額だけを比べ、同じ金額の普通のHashとも等しい" do
      other = sample.tap { |amounts| amounts.rounding_errors["bs.assets"] = 1_000.to_d }
      expect(sample).to eq other
      expect(sample).to eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000)
    end
  end

  describe "#dup" do
    it "金額と端数を、元と別の表に複製する" do
      original = sample
      copy = original.dup
      expect(copy).to be_a(described_class)
      expect(copy).to eq original
      expect(copy.rounding_errors).to eq original.rounding_errors

      copy.store("bs.assets", 1, 1.to_d)
      copy.store("cf.cash_end", 2, 1.to_d)
      expect(original).to eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000)
      expect(original.rounding_errors).to eq("bs.assets" => 1_000_000.to_d, "pl.revenue" => nil)
    end

    it "凍結したものを複製すると、金額も端数も書き換えられる" do
      original = sample
      original.rounding_errors.freeze
      original.freeze
      copy = original.dup
      copy.store("bs.assets", 1, 1.to_d)
      expect(copy["bs.assets"]).to eq 1
      expect(copy.rounding_errors["bs.assets"]).to eq 1.to_d
    end
  end

  # 内部で複製するHashのメソッドは、dupを変えた後も今と同じ結果を返す
  describe "複製を伴うHashのメソッド" do
    it "merge・compact は Amounts を返し、端数の表を複製せずに元と共有する" do
      original = sample
      merged = original.merge("cf.cash_end" => 10_000_000)
      expect(merged).to be_a(described_class)
      expect(merged).to eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000, "cf.cash_end" => 10_000_000)
      expect(merged.rounding_errors).to equal original.rounding_errors

      compacted = original.compact
      expect(compacted).to be_a(described_class)
      expect(compacted).to eq original
      expect(compacted.rounding_errors).to equal original.rounding_errors
    end

    it "slice・except・select・reject・to_h は、端数を持たない金額だけの普通のHashを返す" do
      results = [ sample.slice("bs.assets"), sample.except("pl.revenue"), sample.select { |code, _| code == "bs.assets" },
                  sample.reject { |code, _| code == "pl.revenue" } ]
      expect(results).to all(be_an_instance_of(Hash).and(eq("bs.assets" => 100_000_000)))
      expect(sample.to_h).to be_an_instance_of(Hash)
    end
  end
end
