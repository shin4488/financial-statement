require "rails_helper"

RSpec.describe FinancialStatements::StatementData do
  # 百万円単位で開示した資産合計
  def amounts(assets = 100_000_000)
    FinancialStatements::Amounts.new.tap { |result| result.store("bs.assets", assets, 1_000_000.to_d) }
  end

  def build(**overrides)
    described_class.new(consolidation_type: :consolidated, accounting_standard: "ifrs", presentation_format: "ifrs_classified",
                        amounts: amounts, disclosed_roe: BigDecimal("0.081"), fiscal_year_end_date: Date.new(2026, 3, 31),
                        **overrides)
  end

  it "連結区分・会計基準・形式・金額・公表ROE・決算日を持つ" do
    data = build
    expect(data).to have_attributes(consolidation_type: :consolidated, accounting_standard: "ifrs",
                                    presentation_format: "ifrs_classified", disclosed_roe: BigDecimal("0.081"),
                                    fiscal_year_end_date: Date.new(2026, 3, 31))
    expect(data.amounts).to eq("bs.assets" => 100_000_000)
    expect(data.amounts.rounding_errors).to eq("bs.assets" => 1_000_000.to_d)
  end

  it "属性が足りなければ作れない" do
    expect {
      described_class.new(consolidation_type: :consolidated, amounts: amounts, accounting_standard: "ifrs")
    }.to raise_error(ArgumentError, /missing keyword/)
  end

  describe "連結区分" do
    it "ARモデルと同じ文字列で渡しても、シンボルで持つ" do
      expect(build(consolidation_type: "consolidated").consolidation_type).to eq :consolidated
      expect(build(consolidation_type: "non_consolidated").consolidation_type).to eq :non_consolidated
    end
  end

  describe "金額" do
    it "作った後は、金額も端数も書き換えられない" do
      data = build
      expect { data.amounts["bs.assets"] = 1 }.to raise_error(FrozenError)
      expect { data.amounts.store("bs.assets", 1, 1.to_d) }.to raise_error(FrozenError)
      expect { data.amounts.rounding_errors["bs.assets"] = 1.to_d }.to raise_error(FrozenError)
    end

    it "渡した金額は凍結せず、作った後に書き換えても値に伝わらない" do
      source = amounts
      data = build(amounts: source)
      expect(source).not_to be_frozen
      expect(source.rounding_errors).not_to be_frozen

      source.store("bs.assets", 1, 1.to_d)
      expect(data.amounts).to eq("bs.assets" => 100_000_000)
      expect(data.amounts.rounding_errors).to eq("bs.assets" => 1_000_000.to_d)
    end

    it "属性を変えて作り直した値の金額も、書き換えられない" do
      data = build.with(disclosed_roe: nil)
      expect(data.disclosed_roe).to be_nil
      expect(data.amounts).to be_frozen
      expect(data.amounts.rounding_errors).to be_frozen
    end
  end

  describe "等しさ" do
    it "属性の値が同じなら、別に作っても等しく、Hashのキーとしても同じものになる" do
      expect(build).to eq build
      expect(build).to eql build
      expect({ build => 1 }).to have_key(build)
    end

    it "抽出結果（シンボル）とARモデル（文字列）の連結区分から作ったものは等しい" do
      expect(build(consolidation_type: "consolidated")).to eq build(consolidation_type: :consolidated)
    end

    it "金額や連結区分が違えば等しくない" do
      expect(build(amounts: amounts(100_000_001))).not_to eq build
      expect(build(consolidation_type: :non_consolidated)).not_to eq build
    end
  end
end
