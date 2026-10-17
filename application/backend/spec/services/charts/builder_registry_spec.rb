require "rails_helper"

RSpec.describe Charts::BuilderRegistry do
  it "Formatsの全形式（unsupported以外）にBS/PLのBuilderが対応している" do
    supported = FinancialStatements::Formats::ALL - [ FinancialStatements::Formats::UNSUPPORTED ]
    expect(described_class::BS.keys).to match_array(supported)
    expect(described_class::PL.keys).to match_array(supported)
  end

  it "unsupported形式はBS/PLがunrenderableになり、CFは科目があれば描ける" do
    fs = create(:disclosure_financial_statement, presentation_format: "unsupported",
                amounts: { "cf.cash_begin" => 1, "cf.operating" => 2, "cf.investing" => 3,
                              "cf.financing" => 4, "cf.cash_end" => 10 })
    charts = described_class.build_all(fs.to_statement_data)
    expect(charts[:balance_sheet].renderable).to be false
    expect(charts[:profit_loss].renderable).to be false
    expect(charts[:cash_flow].renderable).to be true
  end

  it "有報の決算日をグラフ作成処理に渡し、説明文を年度で分ける" do
    report = create(:disclosure_report, fiscal_year_start_date: Date.new(2017, 4, 1), fiscal_year_end_date: Date.new(2018, 3, 31))
    fs = create(:disclosure_financial_statement, report: report, presentation_format: "ifrs_summary",
                amounts: { "bs.assets" => 1_000 })
    expect(described_class.build_all(fs.to_statement_data)[:balance_sheet].note).to eq "財政状態計算書: 2019年3月末より前のIFRSは非対応です。"
  end

  describe "StatementData を受ける" do
    let(:items) do
      {
        "bs.current_assets" => 3_090_503_000_000, "bs.non_current_assets" => 12_421_004_000_000,
        "bs.assets" => 15_511_506_000_000, "bs.current_liabilities" => 2_832_074_000_000,
        "bs.non_current_liabilities" => 5_248_784_000_000, "bs.equity" => 7_430_649_000_000,
        "pl.revenue" => 4_505_720_000_000, "pl.cost_of_sales" => 1_571_588_000_000,
        "pl.sga" => 1_084_215_000_000, "pl.profit_before_tax" => -142_355_000_000,
        "cf.cash_begin" => 385_113_000_000, "cf.operating" => 1_041_431_000_000,
        "cf.investing" => -369_141_000_000, "cf.financing" => -496_820_000_000,
        "cf.cash_end" => 595_054_000_000
      }
    end

    # 凍結していない金額の表と決算日を、形式のBuilderに直接渡して組み立てたグラフ
    def charts_from(items, format, date)
      unrenderable = Charts::StackChart.unrenderable(described_class::UNSUPPORTED_NOTE)
      { balance_sheet: described_class::BS[format]&.new(items, fiscal_year_end_date: date)&.build || unrenderable,
        profit_loss: described_class::PL[format]&.new(items, fiscal_year_end_date: date)&.build || unrenderable,
        cash_flow: Charts::Builders::CashFlow.new(items).build }
    end

    it "凍結した金額から、どの形式でも凍結していない金額の表をBuilderに渡したときと同じグラフを組み立てる" do
      FinancialStatements::Formats::ALL.each do |format|
        fs = create(:disclosure_financial_statement, presentation_format: format, amounts: items)
        statement_data = fs.to_statement_data
        expect(statement_data.amounts).to be_frozen
        expect(fs.amounts).not_to be_frozen
        expect(described_class.build_all(statement_data)).to eq(charts_from(fs.amounts, format, fs.report.fiscal_year_end_date)), format
      end
    end

    it "決算日を StatementData から読み、説明文を年度で分ける" do
      statement_data = FinancialStatements::StatementData.new(
        consolidation_type: :consolidated, accounting_standard: "ifrs", presentation_format: "ifrs_summary",
        amounts: FinancialStatements::Amounts.new, disclosed_roe: nil, fiscal_year_end_date: Date.new(2018, 3, 31))
      expect(described_class.build_all(statement_data)[:balance_sheet].note).to eq "財政状態計算書: 2019年3月末より前のIFRSは非対応です。"
    end
  end
end
