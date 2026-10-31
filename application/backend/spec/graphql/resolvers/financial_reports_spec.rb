require "rails_helper"

RSpec.describe "financialReports query" do
  # 定数でなくlet: describe内のトップレベル定数はObjectにリークして他specから見えてしまうため
  let(:query) { <<~GRAPHQL }
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
        cashFlow { renderable steps { key label amount kind colorRole } }
        freeCashFlowTrend { renderable note points { year operatingCf investingCf amount } }
      }
    }
  GRAPHQL

  let!(:financial_statement) do
    create(:disclosure_financial_statement,
           report: create(:disclosure_report,
                          company: create(:disclosure_company, stock_code: "45020", name_ja: "現在の社名"),
                          company_name_ja: "提出時点の社名"),
           amounts: {
             "bs.current_assets" => 3_090_503_000_000, "bs.non_current_assets" => 12_421_004_000_000,
             "bs.assets" => 15_511_506_000_000, "bs.current_liabilities" => 2_832_074_000_000,
             "bs.non_current_liabilities" => 5_248_784_000_000, "bs.equity" => 7_430_649_000_000,
             "pl.revenue" => 4_505_720_000_000, "pl.cost_of_sales" => 1_571_588_000_000,
             "pl.sga" => 1_084_215_000_000, "pl.profit_before_tax" => -142_355_000_000,
             "cf.cash_begin" => 385_113_000_000, "cf.operating" => 1_041_431_000_000,
             "cf.investing" => -369_141_000_000, "cf.financing" => -496_820_000_000,
             "cf.cash_end" => 595_054_000_000
           })
  end

  def execute(variables)
    FinancialStatementSchema.execute(query, variables: variables).to_h
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

    cf_steps = report.dig("cashFlow", "steps")
    expect(cf_steps.size).to eq 5
    # 投資CFは負のためcashDecrease（色の決定はバックエンドの契約）
    expect(cf_steps.find { |s| s["key"] == "investing" }["colorRole"]).to eq "cashDecrease"
    trend = report["freeCashFlowTrend"]
    expect(trend["renderable"]).to be true
    expect(trend["points"].last).to include("year" => 2026,
                                           "operatingCf" => 1_041_431_000_000,
                                           "investingCf" => -369_141_000_000,
                                           "amount" => 672_290_000_000)
  end

  describe "絞り込みの引数" do
    # 上の有報（4502）は 営業CF+・投資CF−・財務CF−。
    # こちらは 営業CF−・投資CF+・財務CF− にし、どの引数をどの活動のCFと取り違えても、返る有報が変わるようにする
    before do
      create(:disclosure_financial_statement,
             report: create(:disclosure_report, company: create(:disclosure_company, stock_code: "391A0")),
             amounts: { "cf.operating" => -10, "cf.investing" => 20, "cf.financing" => -30 })
    end

    def stock_codes_for(arguments)
      result = FinancialStatementSchema.execute("{ financialReports(limit: 10, offset: 0, #{arguments}) { stockCode } }").to_h
      expect(result["errors"]).to be_nil
      result.dig("data", "financialReports").map { |report| report["stockCode"] }
    end

    it "stockCodesは画面と同じ4桁（英字を含むコードも）で受け取り、指定した証券コードの有報だけを返す" do
      expect(stock_codes_for('stockCodes: ["391A"]')).to eq [ "391A" ]
      expect(stock_codes_for('stockCodes: ["4502", "391A"]')).to contain_exactly("4502", "391A")
      expect(stock_codes_for('stockCodes: ["7203"]')).to eq []
    end

    it "operatingCfSign・investingCfSign・financingCfSignは、それぞれ営業・投資・財務のCFの符号で絞り込む" do
      aggregate_failures do
        expect(stock_codes_for("operatingCfSign: POSITIVE")).to eq [ "4502" ]
        expect(stock_codes_for("operatingCfSign: NEGATIVE")).to eq [ "391A" ]
        expect(stock_codes_for("investingCfSign: POSITIVE")).to eq [ "391A" ]
        expect(stock_codes_for("investingCfSign: NEGATIVE")).to eq [ "4502" ]
        expect(stock_codes_for("financingCfSign: POSITIVE")).to eq []
        expect(stock_codes_for("financingCfSign: NEGATIVE")).to contain_exactly("4502", "391A")
        expect(stock_codes_for("operatingCfSign: NEGATIVE, investingCfSign: POSITIVE, financingCfSign: NEGATIVE")).to eq [ "391A" ]
      end
    end

    it "CFが0の有報は、正・負のどちらの絞り込みにも含めない" do
      create(:disclosure_financial_statement,
             report: create(:disclosure_report, company: create(:disclosure_company, stock_code: "99990")),
             amounts: { "cf.operating" => 0, "cf.investing" => 0, "cf.financing" => 0 })

      aggregate_failures do
        %w[operatingCfSign investingCfSign financingCfSign].product(%w[POSITIVE NEGATIVE]).each do |argument, sign|
          expect(stock_codes_for("#{argument}: #{sign}")).not_to include("9999"), "#{argument}: #{sign}"
        end
      end
    end
  end

  it "企業マスタの証券コードがない有報は、stockCodeをnull（空文字なら空文字）で返す" do
    company = financial_statement.report.company
    { nil => nil, "" => "" }.each do |stored, displayed|
      company.update!(stock_code: stored)
      result = execute({ "limit" => 10, "offset" => 0 })
      expect(result["errors"]).to be_nil
      expect(result.dig("data", "financialReports", 0, "stockCode")).to eq displayed
    end
  end

  it "会計基準・連結区分・形式は、保存した文字列のまま返す" do
    report = execute({ "limit" => 10, "offset" => 0 }).dig("data", "financialReports", 0)
    expect(report.values_at("accountingStandard", "consolidationType", "presentationFormat"))
      .to eq %w[ifrs consolidated ifrs_classified]

    financial_statement.update!(consolidation_type: :non_consolidated)
    expect(execute({ "limit" => 10, "offset" => 0 }).dig("data", "financialReports", 0, "consolidationType"))
      .to eq "non_consolidated"
  end

  it "提出日がない有報は、filingDateをnullで返し、提出日のある有報の後に並べる" do
    create(:disclosure_financial_statement, report: create(:disclosure_report, filing_date: nil))

    result = FinancialStatementSchema.execute("{ financialReports(limit: 10, offset: 0) { filingDate } }").to_h

    expect(result.dig("data", "financialReports").map { |report| report["filingDate"] }).to eq [ "2026-06-20", nil ]
  end
end
