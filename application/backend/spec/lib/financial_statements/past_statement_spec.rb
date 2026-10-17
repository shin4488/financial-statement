require "rails_helper"

RSpec.describe FinancialStatements::PastStatement do
  # 百万円単位で開示した営業CF
  def amounts(operating = 30_000_000)
    FinancialStatements::Amounts.new.tap { |result| result.store("cf.operating", operating, 1_000_000.to_d) }
  end

  def build(**overrides)
    described_class.new(company_id: 1, fiscal_year_start_date: Date.new(2024, 4, 1), fiscal_year_end_date: Date.new(2025, 3, 31),
                        consolidation_type: :consolidated, amounts: amounts, **overrides)
  end

  it "ARモデルと同じ文字列の連結区分で渡しても、シンボルで持つ" do
    expect(build(consolidation_type: "non_consolidated").consolidation_type).to eq :non_consolidated
  end

  it "金額と端数を持ち、作った後は書き換えられない" do
    statement = build
    expect(statement.amounts.to_h).to eq("cf.operating" => 30_000_000)
    expect(statement.amounts.rounding_errors).to eq("cf.operating" => 1_000_000.to_d)
    expect(statement.amounts).to be_frozen
    expect { statement.amounts.store("cf.operating", 1, 1.to_d) }.to raise_error(FrozenError)
    expect(statement.amounts.rounding_errors).to be_frozen
  end

  it "渡した金額は凍結せず、作った後に書き換えても値に伝わらない" do
    source = amounts
    statement = build(amounts: source)
    expect(source).not_to be_frozen
    expect(source.rounding_errors).not_to be_frozen

    source.store("cf.operating", 1, 1.to_d)
    expect(statement.amounts.to_h).to eq("cf.operating" => 30_000_000)
    expect(statement.amounts.rounding_errors).to eq("cf.operating" => 1_000_000.to_d)
  end
end
