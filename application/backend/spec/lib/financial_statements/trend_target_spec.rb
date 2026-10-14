require "rails_helper"

RSpec.describe FinancialStatements::TrendTarget do
  it "推移に並べる年は、決算日の暦年までの5年を古い順にする" do
    target = described_class.new(report_id: 1, company_id: 2, fiscal_year_end_date: Date.new(2024, 12, 31))
    expect(target.years.to_a).to eq [ 2020, 2021, 2022, 2023, 2024 ]
  end
end
