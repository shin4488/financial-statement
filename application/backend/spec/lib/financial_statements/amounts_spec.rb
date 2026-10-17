require "rails_helper"

RSpec.describe FinancialStatements::Amounts do
  # 百万円単位で開示した資産合計と、精度の分からない売上
  def sample
    described_class.new.tap do |amounts|
      amounts.store("bs.assets", 100_000_000, 1_000_000.to_d)
      amounts.store("pl.revenue", 50_000_000, nil)
    end
  end

  describe "#store" do
    it "金額と端数の上限を組で書き、金額を返す" do
      amounts = described_class.new
      expect(amounts.store("bs.assets", 100_000_000, 1_000_000.to_d)).to eq 100_000_000
      expect(amounts.to_h).to eq("bs.assets" => 100_000_000)
      expect(amounts.rounding_errors).to eq("bs.assets" => 1_000_000.to_d)
    end

    it "精度の分からない端数（nil）も、科目のキーを作って書く" do
      amounts = described_class.new
      amounts.store("pl.revenue", 50_000_000, nil)
      expect(amounts.rounding_errors).to have_key("pl.revenue")
      expect(amounts.rounding_errors["pl.revenue"]).to be_nil
    end

    it "同じ科目に書くと、金額と端数の両方を置き換える" do
      amounts = sample
      amounts.store("bs.assets", 200_000_000, 1_000.to_d)
      expect(amounts.to_h).to eq("bs.assets" => 200_000_000, "pl.revenue" => 50_000_000)
      expect(amounts.rounding_errors).to eq("bs.assets" => 1_000.to_d, "pl.revenue" => nil)
    end

    it "端数は省けない" do
      expect { described_class.new.store("bs.assets", 100_000_000) }.to raise_error(ArgumentError)
    end

    it "store のほかに、Hashの書き方で書く操作を持たない" do
      expect(sample).not_to respond_to(:[]=, :merge!, :update, :delete)
    end
  end

  describe "読む" do
    it "科目の金額と端数を、科目コードで読む" do
      amounts = sample
      expect(amounts["bs.assets"]).to eq 100_000_000
      expect(amounts["cf.cash_end"]).to be_nil
      expect(amounts.values_at("pl.revenue", "cf.cash_end")).to eq [ 50_000_000, nil ]
      expect(amounts.rounding_error("bs.assets")).to eq 1_000_000.to_d
      expect(amounts.rounding_error("pl.revenue")).to be_nil
    end

    it "科目があるかを、書いた順の科目コードとあわせて答える" do
      amounts = sample
      expect(amounts.key?("pl.revenue")).to be true
      expect(amounts.key?("cf.cash_end")).to be false
      expect(amounts.codes).to eq %w[bs.assets pl.revenue]
      expect(amounts).not_to be_empty
      expect(described_class.new).to be_empty
    end

    it "科目コードと金額の組を、書いた順に繰り返す" do
      amounts = sample
      expect(amounts.map { |code, amount| [ code, amount ] }).to eq [ [ "bs.assets", 100_000_000 ], [ "pl.revenue", 50_000_000 ] ]
      expect(amounts.each { |_code, _amount| nil }).to equal amounts
      expect(amounts.each.to_a).to eq [ [ "bs.assets", 100_000_000 ], [ "pl.revenue", 50_000_000 ] ]
    end
  end

  describe "#same_values?" do
    it "金額が同じなら、端数が違っても真" do
      other = sample.tap { |amounts| amounts.store("bs.assets", 100_000_000, 1_000.to_d) }
      expect(sample.same_values?(other)).to be true
    end

    it "金額が違えば偽" do
      other = sample.tap { |amounts| amounts.store("bs.assets", 100_000_001, 1_000_000.to_d) }
      expect(sample.same_values?(other)).to be false
    end

    it "片方にしかない科目があれば偽" do
      other = sample.tap { |amounts| amounts.store("cf.cash_end", 10_000_000, nil) }
      expect(sample.same_values?(other)).to be false
      expect(other.same_values?(sample)).to be false
    end
  end

  describe "#==" do
    it "金額と端数がどちらも同じなら、別に作っても等しく、Hashのキーとしても同じものになる" do
      expect(sample).to eq sample
      expect(sample).to eql sample
      expect(sample.hash).to eq sample.hash
      expect({ sample => 1 }).to have_key(sample)
    end

    it "金額が同じでも、端数が違えば等しくない" do
      other = sample.tap { |amounts| amounts.store("bs.assets", 100_000_000, 1_000.to_d) }
      expect(sample).not_to eq other
      expect(sample).not_to eql other
    end

    it "金額が違えば等しくない" do
      other = sample.tap { |amounts| amounts.store("bs.assets", 100_000_001, 1_000_000.to_d) }
      expect(sample).not_to eq other
    end

    it "同じ金額の普通のHashとは等しくない" do
      expect(sample).not_to eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000)
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
      expect(original.to_h).to eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000)
      expect(original.rounding_errors).to eq("bs.assets" => 1_000_000.to_d, "pl.revenue" => nil)
    end

    it "凍結したものを複製すると、金額も端数も書き換えられる" do
      original = sample.freeze
      copy = original.dup
      copy.store("bs.assets", 1, 1.to_d)
      expect(copy["bs.assets"]).to eq 1
      expect(copy.rounding_errors["bs.assets"]).to eq 1.to_d
    end
  end

  describe "#freeze" do
    it "金額と端数の両方の表を凍結する" do
      amounts = sample.freeze
      expect { amounts.store("bs.assets", 1, 1.to_d) }.to raise_error(FrozenError)
      expect(amounts.rounding_errors).to be_frozen
      expect(amounts.to_h).to eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000)
    end

    it "凍結したものを clone すると、複製も金額と端数を書き換えられない" do
      copy = sample.freeze.clone
      expect(copy).to eq sample
      expect { copy.store("bs.assets", 1, 1.to_d) }.to raise_error(FrozenError)
      expect(copy.rounding_errors).to be_frozen
    end

    it "凍結していないものの clone は、元と別の表に書き換えられる" do
      original = sample
      copy = original.clone
      copy.store("bs.assets", 1, 1.to_d)
      expect(copy.rounding_errors["bs.assets"]).to eq 1.to_d
      expect(original["bs.assets"]).to eq 100_000_000
      expect(original.rounding_errors["bs.assets"]).to eq 1_000_000.to_d
    end
  end

  # Sentryのextra（amounts:）とspecが、金額だけの普通のHashを前提にしている
  describe "一部を取り出す" do
    it "slice・except・to_h は、端数を持たない金額だけの普通のHashを返す" do
      results = [ sample.slice("bs.assets"), sample.except("pl.revenue") ]
      expect(results).to all(be_an_instance_of(Hash).and(eq("bs.assets" => 100_000_000)))
      expect(sample.to_h).to be_an_instance_of(Hash).and(eq("bs.assets" => 100_000_000, "pl.revenue" => 50_000_000))
    end

    it "取り出したHashに書いても、元の金額は変わらない" do
      amounts = sample
      amounts.to_h["bs.assets"] = 1
      amounts.slice("bs.assets")["bs.assets"] = 1
      expect(amounts["bs.assets"]).to eq 100_000_000
    end
  end
end
