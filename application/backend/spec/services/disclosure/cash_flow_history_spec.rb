require "rails_helper"

RSpec.describe Disclosure::CashFlowHistory do
  let(:company) { create(:disclosure_company) }

  def report(year, company: self.company)
    create(:disclosure_report, company: company,
           fiscal_year_start_date: Date.new(year - 1, 4, 1), fiscal_year_end_date: Date.new(year, 3, 31),
           filing_date: Date.new(year, 6, 20))
  end

  def statement(year, items = {}, company: self.company, **attributes)
    create(:disclosure_financial_statement, report: report(year, company: company), amounts: items, **attributes)
  end

  def target(report)
    FinancialStatements::TrendTarget.new(report_id: report.id, company_id: report.company_id,
                                         fiscal_year_end_date: report.fiscal_year_end_date)
  end

  it "同じ企業の推移に並べる年の主の財務諸表を、CFの式に使う科目だけで読む" do
    current = statement(2025, { "cf.operating" => 30_000_000, "cf.investing" => -10_000_000, "bs.assets" => 500_000_000 })
    statement(2021, { "cf.cash_begin" => 1_000, "cf.exchange_effect" => 10, "cf.cash_end" => 2_000 },
              consolidation_type: :non_consolidated)
    statement(2020, { "cf.operating" => 1 })
    statement(2026, { "cf.operating" => 2 })
    create(:disclosure_financial_statement, report: current.report, consolidation_type: :non_consolidated, is_primary: false,
           amounts: { "cf.operating" => 3 })
    statement(2024, { "cf.operating" => 4 }, company: create(:disclosure_company))

    history = described_class.new.load([ target(current.report) ])

    expect(history.map { |past| [ past.fiscal_year_end_date.year, past.consolidation_type, past.amounts.to_h ] })
      .to contain_exactly([ 2025, :consolidated, { "cf.operating" => 30_000_000, "cf.investing" => -10_000_000 } ],
                          [ 2021, :non_consolidated, { "cf.cash_begin" => 1_000, "cf.exchange_effect" => 10, "cf.cash_end" => 2_000 } ])
    expect(history.find { |past| past.fiscal_year_end_date.year == 2025 })
      .to have_attributes(company_id: company.id, fiscal_year_start_date: Date.new(2024, 4, 1))
  end

  it "科目の端数も読む。CFの科目がない財務諸表は、空の金額で返す" do
    current = statement(2025)
    create(:disclosure_financial_statement_item, financial_statement: statement(2024), item_code: "cf.operating",
           amount: 30_000_000, rounding_error: 1_000_000)

    history = described_class.new.load([ target(current.report) ]).index_by { |past| past.fiscal_year_end_date.year }

    expect(history[2025].amounts).to be_empty
    expect(history[2024].amounts.rounding_errors).to eq("cf.operating" => 1_000_000)
  end

  it "決算日の違う有報を並べたときは、最も古い有報の推移の最初の年から、最も新しい有報の決算の年までを読む" do
    older = statement(2022)
    newer = statement(2025)
    statement(2018)
    statement(2017)

    history = described_class.new.load([ target(newer.report), target(older.report) ])

    expect(history.map { |past| past.fiscal_year_end_date.year }).to contain_exactly(2018, 2022, 2025)
  end

  it "12月決算の有報は、その年の12月末の決算まで読む" do
    december = create(:disclosure_report, company: company, fiscal_year_start_date: Date.new(2025, 1, 1),
                      fiscal_year_end_date: Date.new(2025, 12, 31), filing_date: Date.new(2026, 3, 20))
    create(:disclosure_financial_statement, report: december)

    history = described_class.new.load([ target(december) ])

    expect(history.map(&:fiscal_year_end_date)).to eq [ Date.new(2025, 12, 31) ]
  end

  it "有報の件数によらず、問い合わせは3回にする" do
    reports = Array.new(3) { report(2025, company: create(:disclosure_company)) }
    reports.each { |r| create(:disclosure_financial_statement, report: r, amounts: { "cf.operating" => 1 }) }

    expect(count_queries { described_class.new.load(reports.first(1).map { |r| target(r) }) }).to eq 3
    expect(count_queries { described_class.new.load(reports.map { |r| target(r) }) }).to eq 3
  end

  it "有報がなければ、問い合わせずに空を返す" do
    expect(count_queries { expect(described_class.new.load([])).to eq [] }).to eq 0
  end
end
