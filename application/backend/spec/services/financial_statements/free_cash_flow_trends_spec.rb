require "rails_helper"

RSpec.describe FinancialStatements::FreeCashFlowTrends do
  let(:company) { create(:disclosure_company) }

  def statement(year, operating: nil, investing: nil, consolidation_type: :consolidated)
    report = create(:disclosure_report, company: company,
                    fiscal_year_start_date: Date.new(year - 1, 4, 1),
                    fiscal_year_end_date: Date.new(year, 3, 31),
                    filing_date: Date.new(year, 6, 20))
    items = {}
    items["cf.operating"] = operating unless operating.nil?
    items["cf.investing"] = investing unless investing.nil?
    create(:disclosure_financial_statement, report: report,
           consolidation_type: consolidation_type, items_hash: items)
    report
  end

  it "対象期を含む5年を古い順に返し、欠損・0円・負値を区別する" do
    current = statement(2025, operating: 30_000_000, investing: -10_000_000)
    statement(2024, operating: -3_000_000, investing: -2_000_000)
    statement(2023, operating: 4_000_000)
    statement(2021, operating: 0, investing: 0)
    statement(2026, operating: 99_000_000, investing: 0)

    trend = described_class.build([ current ]).fetch(current.id)

    expect(trend.renderable).to be true
    expect(trend.points.map(&:year)).to eq [ 2021, 2022, 2023, 2024, 2025 ]
    expect(trend.points.map(&:amount)).to eq [ 0, nil, nil, -5_000_000, 20_000_000 ]
    expect(trend.points[1].fiscal_year_end_date).to be_nil
    expect(trend.points[2].investing_cf).to be_nil
    expect(trend.points[4].fiscal_year_end_date).to eq "2025-03-31"
  end

  it "連結・単体が切り替わっても各年の主たる財務諸表を表示し、区分を明記する" do
    current = statement(2025, operating: 30_000_000, investing: -10_000_000)
    statement(2024, operating: 80_000_000, investing: 20_000_000,
             consolidation_type: :non_consolidated)
    statement(2023, operating: 40_000_000, investing: -10_000_000,
             consolidation_type: :non_consolidated)
    statement(2022, operating: 50_000_000, investing: -20_000_000)

    trend = described_class.build([ current ]).fetch(current.id)

    expect(trend.renderable).to be true
    expect(trend.points.map(&:amount)).to eq [ nil, 30_000_000, 30_000_000, 100_000_000, 20_000_000 ]
    expect(trend.note).to eq "連結区分：2022年 連結 → 2023～2024年 単体 → 2025年 連結"
  end

  it "過年度の副次的な財務諸表は使わず、主たる財務諸表にCFがなければ欠損とする" do
    current = statement(2025)
    earlier = statement(2024, operating: 80_000_000,
                        consolidation_type: :non_consolidated)
    create(:disclosure_financial_statement, report: earlier,
           consolidation_type: :consolidated, is_primary: false,
           items_hash: { "cf.operating" => 80_000_000, "cf.investing" => 20_000_000 })

    trend = described_class.build([ current ]).fetch(current.id)

    expect(trend.renderable).to be false
    expect(trend.note).to eq "過去5年のデータがありません"
    expect(trend.points.map(&:amount)).to eq [ nil ] * 5
  end

  it "活動がなく投資CFの行がない年は、CFのグラフと同じくCFの式が成り立つときだけ0として扱う" do
    current = statement(2025, operating: 30_000_000)
    current.primary_financial_statement.tap do |fs|
      { "cf.cash_begin" => 100_000_000, "cf.financing" => -5_000_000, "cf.cash_end" => 125_000_000 }.each do |code, amount|
        create(:disclosure_financial_statement_item, financial_statement: fs, item_code: code, amount: amount)
      end
    end
    unbalanced = statement(2024, operating: 30_000_000)
    unbalanced.primary_financial_statement.tap do |fs|
      { "cf.cash_begin" => 100_000_000, "cf.cash_end" => 125_000_000 }.each do |code, amount|
        create(:disclosure_financial_statement_item, financial_statement: fs, item_code: code, amount: amount)
      end
    end

    trend = described_class.build([ current ]).fetch(current.id)

    expect(trend.points[4]).to have_attributes(operating_cf: 30_000_000, investing_cf: 0, amount: 30_000_000)
    expect(trend.points[3]).to have_attributes(operating_cf: 30_000_000, investing_cf: nil, amount: nil)
  end

  it "年内に複数期がある場合は対象期以前の最新の決算期を使う" do
    current = statement(2025, operating: 20_000_000, investing: -5_000_000)
    statement(2024, operating: 10_000_000, investing: -2_000_000)
    later = create(:disclosure_report, company: company,
                   fiscal_year_start_date: Date.new(2024, 4, 1),
                   fiscal_year_end_date: Date.new(2024, 12, 31),
                   filing_date: Date.new(2025, 2, 20))
    create(:disclosure_financial_statement, report: later,
           items_hash: { "cf.operating" => 6_000_000, "cf.investing" => -1_000_000 })
    future = create(:disclosure_report, company: company,
                    fiscal_year_start_date: Date.new(2025, 4, 1),
                    fiscal_year_end_date: Date.new(2025, 12, 31),
                    filing_date: Date.new(2026, 2, 20))
    create(:disclosure_financial_statement, report: future,
           items_hash: { "cf.operating" => 99_000_000, "cf.investing" => 0 })

    trend = described_class.build([ current ]).fetch(current.id)

    expect(trend.points[3].fiscal_year_end_date).to eq "2024-12-31"
    expect(trend.points[3].amount).to eq 5_000_000
    expect(trend.points[4].amount).to eq 15_000_000
  end
end
