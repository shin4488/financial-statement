require "rails_helper"

RSpec.describe Disclosure::SearchQuery do
  subject(:query) { described_class.new }

  let!(:positive_cf_report) do
    create(:disclosure_financial_statement,
           report: create(:disclosure_report,
                          company: create(:disclosure_company, stock_code: "72030"),
                          filing_date: Date.new(2026, 6, 25)),
           items_hash: { "cf.operating" => 100, "cf.investing" => -50, "cf.financing" => -30 }).report
  end
  let!(:negative_cf_report) do
    create(:disclosure_financial_statement,
           report: create(:disclosure_report,
                          company: create(:disclosure_company, stock_code: "45020"),
                          filing_date: Date.new(2026, 6, 20)),
           items_hash: { "cf.operating" => -200, "cf.investing" => 80, "cf.financing" => 40 }).report
  end

  it "is_primaryな財務諸表を持つ有報だけが返る" do
    create(:disclosure_financial_statement, is_primary: false,
           consolidation_type: :non_consolidated,
           report: create(:disclosure_report, has_consolidated_statement: false))
    results = query.call(limit: 10, offset: 0)
    expect(results).to contain_exactly(positive_cf_report, negative_cf_report)
  end

  it "提出日降順で返る" do
    expect(query.call(limit: 10, offset: 0).to_a).to eq [ positive_cf_report, negative_cf_report ]
  end

  it "証券コードは4桁入力を5桁に0パディングして照合する" do
    results = query.call(limit: 10, offset: 0, stock_codes: [ "7203" ])
    expect(results).to contain_exactly(positive_cf_report)
  end

  it "CF符号フィルタで絞り込める" do
    results = query.call(limit: 10, offset: 0,
                         cf_signs: { operating: :positive, investing: :negative, financing: :negative })
    expect(results).to contain_exactly(positive_cf_report)

    results = query.call(limit: 10, offset: 0, cf_signs: { operating: :negative })
    expect(results).to contain_exactly(negative_cf_report)
  end

  it "CF科目の行がない有報は符号フィルタにかからない" do
    create(:disclosure_financial_statement, items_hash: { "bs.assets" => 1 })
    results = query.call(limit: 10, offset: 0, cf_signs: { operating: :positive })
    expect(results).to contain_exactly(positive_cf_report)
  end

  it "一部の符号だけ一致する有報は全符号指定のフィルタにかからない" do
    create(:disclosure_financial_statement,
           items_hash: { "cf.operating" => 100, "cf.investing" => -50, "cf.financing" => 30 })
    results = query.call(limit: 10, offset: 0,
                         cf_signs: { operating: :positive, investing: :negative, financing: :negative })
    expect(results).to contain_exactly(positive_cf_report)
  end

  it "証券コードとCF符号の両方を指定するとAND条件で絞り込まれる" do
    results = query.call(limit: 10, offset: 0, stock_codes: [ "7203" ],
                         cf_signs: { operating: :negative })
    expect(results).to be_empty
  end
end
