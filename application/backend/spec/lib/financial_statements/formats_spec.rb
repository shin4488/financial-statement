require "rails_helper"

RSpec.describe FinancialStatements::Formats do
  it "DBに保存する形式名は、対応する7形式と unsupported" do
    expect(described_class::ALL).to contain_exactly(
      "jgaap_general", "jgaap_bank", "jgaap_insurance", "ifrs_classified", "ifrs_liquidity", "ifrs_summary", "usgaap_summary", "unsupported"
    )
  end

  it "形式名の定数はすべて一覧にある" do
    names = (described_class.constants - [ :ALL ]).map { |name| described_class.const_get(name) }
    expect(names).to match_array(described_class::ALL)
  end
end
