require "rails_helper"

RSpec.describe UseCases::ListFinancialReports do
  let(:items) do
    {
      "bs.current_assets" => 300, "bs.non_current_assets" => 700, "bs.assets" => 1_000, "bs.assets_begin" => 1_000,
      "bs.current_liabilities" => 200, "bs.non_current_liabilities" => 300, "bs.equity" => 500,
      "bs.equity_attributable_to_owners" => 500, "bs.equity_attributable_to_owners_begin" => 500,
      "pl.revenue" => 2_000, "pl.profit" => 100, "pl.profit_attributable_to_owners" => 80,
      "cf.cash_begin" => 100, "cf.operating" => 50, "cf.investing" => -20, "cf.financing" => -10, "cf.cash_end" => 120
    }
  end

  def statement(year, consolidation_type: :consolidated, company: create(:disclosure_company))
    report = create(:disclosure_report, company: company,
                    fiscal_year_start_date: Date.new(year - 1, 4, 1), fiscal_year_end_date: Date.new(year, 3, 31),
                    filing_date: Date.new(year, 6, 20))
    create(:disclosure_financial_statement, report: report, consolidation_type: consolidation_type, items_hash: items)
  end

  def call(limit: 10, offset: 0, stock_codes: nil, cf_signs: {}, with_trend: true)
    described_class.new.call(limit: limit, offset: offset, stock_codes: stock_codes, cf_signs: cf_signs, with_trend: with_trend)
  end

  it "有報ごとに、主の財務諸表の値と、それから作ったグラフ・指標・FCF推移を返す" do
    fs = statement(2025)

    entry = call.sole

    expect(entry.report).to eq fs.report
    expect(entry.statement).to have_attributes(consolidation_type: :consolidated, accounting_standard: "ifrs",
                                               presentation_format: "ifrs_classified", fiscal_year_end_date: Date.new(2025, 3, 31))
    expect(entry.statement.amounts).to eq items
    # 保存した科目の表と決算日を、形式のBuilderに直接渡して組み立てたグラフと同じ
    date = Date.new(2025, 3, 31)
    expect(entry.charts).to eq(balance_sheet: Charts::Builders::BsIfrsClassified.new(fs.items_hash, fiscal_year_end_date: date).build,
                               profit_loss: Charts::Builders::PlIfrs.new(fs.items_hash, fiscal_year_end_date: date).build,
                               cash_flow: Charts::Builders::CashFlow.new(fs.items_hash).build)
    metric = ->(value) { FinancialStatements::Indicators::Metric.new(value: value, status: "available", source: "calculated") }
    expect(entry.indicators).to eq(roe: metric.(0.16), roa: metric.(0.08), net_profit_margin: metric.(0.04),
                                   asset_turnover: metric.(2.0), financial_leverage: metric.(2.0))
    point = FinancialStatements::FreeCashFlowTrends::Point
    expect(entry.free_cash_flow_trend).to eq FinancialStatements::FreeCashFlowTrends::Trend.new(
      renderable: true, note: nil,
      points: (2021..2024).map { |year| point.new(year: year) } +
              [ point.new(year: 2025, fiscal_year_start_date: "2024-04-01", fiscal_year_end_date: "2025-03-31",
                          operating_cf: 50, investing_cf: -20, amount: 30, consolidation_type: :consolidated) ])
    expect(entry.free_cash_flow_trend.points.last.amount).to eq 30
  end

  it "単体が主の有報は、連結区分をシンボルで持ち、指標に親会社株主に帰属する利益でなく当期純利益を使う" do
    statement(2025, consolidation_type: :non_consolidated)

    entry = call.sole

    expect(entry.statement.consolidation_type).to eq :non_consolidated
    expect(entry.indicators[:roe].value).to eq 0.2
  end

  it "FCF推移を要求されなければ、作らず、過去の財務諸表も読まない" do
    statement(2025)
    expect(Disclosure::CashFlowHistory).not_to receive(:new)

    expect(call(with_trend: false).sole.free_cash_flow_trend).to be_nil
  end

  it "検索の条件を一覧の検索に渡す" do
    statement(2025, company: create(:disclosure_company, stock_code: "72030"))
    statement(2024, company: create(:disclosure_company, stock_code: "67580"))

    entries = call(stock_codes: [ "7203" ], cf_signs: { investing: :negative })

    expect(entries.map { |entry| entry.report.company.stock_code }).to eq [ "72030" ]
    expect(call(cf_signs: { investing: :positive })).to be_empty
    expect(call(limit: 1).map { |entry| entry.report.company.stock_code }).to eq [ "72030" ]
    expect(call(limit: 1, offset: 1).map { |entry| entry.report.company.stock_code }).to eq [ "67580" ]
  end

  it "有報の件数によらず、問い合わせの回数を同じにする" do
    company = create(:disclosure_company)
    statement(2025, company: company)
    statement(2024, company: company)
    statement(2023, company: create(:disclosure_company))

    [ true, false ].each do |with_trend|
      expect(count_queries { call(limit: 3, with_trend: with_trend) }).to eq(count_queries { call(limit: 1, with_trend: with_trend) })
    end
  end
end
