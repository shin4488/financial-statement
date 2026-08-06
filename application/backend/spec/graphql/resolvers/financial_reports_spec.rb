require "rails_helper"

RSpec.describe "financialReports query" do
  QUERY = <<~GRAPHQL
    query($limit: Int!, $offset: Int!, $operatingCfSign: CashFlowSign) {
      financialReports(limit: $limit, offset: $offset, operatingCfSign: $operatingCfSign) {
        id
        stockCode
        companyName
        accountingStandard
        consolidationType
        presentationFormat
        balanceSheet { renderable note bars { label segments { key label amount signedAmount ratio colorRole } } }
        profitLoss { renderable note bars { label segments { key amount signedAmount } } }
        cashFlow { renderable steps { key label amount kind } }
      }
    }
  GRAPHQL

  let!(:financial_statement) do
    create(:disclosure_financial_statement,
           report: create(:disclosure_report,
                          company: create(:disclosure_company, stock_code: "45020", name_ja: "現在の社名"),
                          company_name_ja: "提出時点の社名"),
           items_hash: {
             "bs.current_assets" => 3_090_503_000_000, "bs.non_current_assets" => 12_421_004_000_000,
             "bs.assets" => 15_511_506_000_000, "bs.current_liabilities" => 2_832_074_000_000,
             "bs.non_current_liabilities" => 5_248_784_000_000, "bs.equity" => 7_430_649_000_000,
             "pl.revenue" => 4_505_720_000_000, "pl.cost_of_sales" => 1_571_588_000_000,
             "pl.sga" => 1_084_215_000_000, "pl.profit_before_tax" => -142_355_000_000,
             "cf.cash_begin" => 385_113_000_000, "cf.operating" => 1_041_431_000_000,
             "cf.investing" => -369_141_000_000, "cf.financing" => -496_820_000_000,
             "cf.cash_end" => 595_054_000_000,
           })
  end

  def execute(variables)
    FinancialStatementSchema.execute(QUERY, variables: variables).to_h
  end

  it "チャート構造が返り、金額はJSON数値（文字列でない）で返る" do
    result = execute({ "limit" => 10, "offset" => 0 })
    expect(result["errors"]).to be_nil
    report = result.dig("data", "financialReports", 0)
    expect(report["stockCode"]).to eq "4502" # 5桁->4桁
    # 社名変更した企業でも各年度は当時の名前で出すため、企業マスタでなく有報側の名前を返す
    expect(report["companyName"]).to eq "提出時点の社名"
    expect(report["presentationFormat"]).to eq "ifrs_classified"

    bs_debit = report.dig("balanceSheet", "bars", 0, "segments")
    expect(bs_debit.map { |s| s["key"] }).to eq %w[currentAssets nonCurrentAssets]
    amount = bs_debit.first["amount"]
    expect(amount).to be_a(Integer) # 文字列シリアライズだとフロント全実装に変換が要るため数値契約を守る
    expect(amount).to eq 3_090_503_000_000

    pl_credit = report.dig("profitLoss", "bars", 1, "segments")
    expect(pl_credit.last["signedAmount"]).to eq(-142_355_000_000)

    expect(report.dig("cashFlow", "steps").size).to eq 5
  end

  it "CF符号フィルタの引数が効く" do
    result = execute({ "limit" => 10, "offset" => 0, "operatingCfSign" => "NEGATIVE" })
    expect(result.dig("data", "financialReports")).to eq []
  end

  it "スキーマにfinancialReportsが定義されている" do
    expect(FinancialStatementSchema.to_definition).to include("financialReports")
  end
end
