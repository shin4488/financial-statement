require "rails_helper"

RSpec.describe UseCases::StatementInspection do
  def statement(items, presentation_format: "jgaap_general", consolidation_type: :non_consolidated)
    amounts = FinancialStatements::Amounts.new
    items.each { |code, amount| amounts.store(code, amount, nil) }
    FinancialStatements::StatementData.new(consolidation_type: consolidation_type, accounting_standard: "japan_gaap",
                                           presentation_format: presentation_format, amounts: amounts,
                                           disclosed_roe: nil, fiscal_year_end_date: nil)
  end

  def extra(amounts) = { doc_id: "S0000001", consolidation_type: "non_consolidated", presentation_format: "jgaap_general", amounts: amounts }

  # 売上が要約の売上と合わず、PLの費用が売上と1割以内でずれ、CFが換算差額の分（10）だけ合わず、資産合計がない
  let(:profit_loss_and_cash_flow) do
    { "pl.revenue" => 1_000, "pl.summary_revenue" => 615, "pl.cost_of_sales" => 600, "pl.sga" => 250, "pl.operating_profit" => 100,
      "cf.cash_begin" => 100, "cf.operating" => 50, "cf.investing" => -30, "cf.financing" => -20, "cf.cash_end" => 110 }
  end
  # 描くBSの借方の科目の合計（989）が資産合計（1,000）に届かない
  let(:balance_sheet) do
    { "bs.current_assets" => 400, "bs.non_current_assets" => 589, "bs.tangible_fixed_assets" => 589, "bs.assets" => 1_000,
      "bs.current_liabilities" => 300, "bs.non_current_liabilities" => 300, "bs.liabilities" => 600, "bs.equity" => 400 }
  end

  describe ".notices" do
    it "資産合計の欠落 → 売上 → PL → CF の順に通知を並べる。照合の警告は照合に使った金額を付加情報にする" do
      notices = described_class.notices(statement(profit_loss_and_cash_flow), primary: true, doc_id: "S0000001").to_a

      expect(notices.map { |notice| [ notice.message, notice.options ] }).to eq [
        [ "primary statement missing bs.assets: S0000001 (jgaap_general)",
          { level: :warning, fingerprint: [ "primary statement missing bs.assets" ] } ],
        [ "revenue does not match summary of business results",
          { level: :warning, fingerprint: [ "revenue does not match summary of business results" ],
            extra: extra("pl.revenue" => 1_000, "pl.summary_revenue" => 615) } ],
        [ "profit and loss chart expenses do not reconcile",
          { level: :warning, fingerprint: [ "profit and loss chart expenses do not reconcile" ],
            extra: extra("pl.revenue" => 1_000, "pl.cost_of_sales" => 600, "pl.sga" => 250, "pl.operating_profit" => 100) } ],
        [ "cash flow does not reconcile with closing balance",
          { level: :warning, fingerprint: [ "cash flow does not reconcile with closing balance" ],
            extra: extra("cf.cash_begin" => 100, "cf.operating" => 50, "cf.investing" => -30, "cf.financing" => -20,
                         "cf.cash_end" => 110) } ]
      ]
    end

    it "BSの照合は売上・PLの後、CFの前に並べる" do
      items = balance_sheet.merge("pl.summary_revenue" => 110, "cf.cash_begin" => 100, "cf.operating" => 5, "cf.cash_end" => 110)
      notices = described_class.notices(statement(items), primary: true, doc_id: "S0000001").to_a

      aggregate_failures do
        expect(notices.map(&:message)).to eq [ "revenue missing although summary of business results has revenue",
                                               "balance sheet chart does not reconcile with totals",
                                               "cash flow does not reconcile with closing balance" ]
        expect(notices.second.extra[:amounts]).to eq("bs.current_assets" => 400, "bs.tangible_fixed_assets" => 589, "bs.assets" => 1_000,
                                                     "bs.liabilities" => 600, "bs.equity" => 400)
      end
    end

    it "主でない財務諸表は点検しない" do
      expect(described_class.notices(statement(profit_loss_and_cash_flow), primary: false, doc_id: "S0000001").to_a).to eq []
    end

    it "合うものと、資産合計を持つものは通知しない" do
      items = { "bs.assets" => 1_000, "pl.revenue" => 615, "pl.summary_revenue" => 615,
                "cf.cash_begin" => 100, "cf.operating" => 10, "cf.cash_end" => 110 }
      expect(described_class.notices(statement(items), primary: true, doc_id: "S0000001").to_a).to eq []
    end

    it "資産合計を作らない形式（unsupported）では資産合計の欠落を、換算差額などの行を読まない形式ではCFの照合を通知しない" do
      cash_flow = profit_loss_and_cash_flow.slice("cf.cash_begin", "cf.operating", "cf.investing", "cf.financing", "cf.cash_end")

      aggregate_failures do
        expect(described_class.notices(statement(cash_flow, presentation_format: "unsupported"), primary: true, doc_id: "S0000001").to_a)
          .to eq []
        expect(described_class.notices(statement(cash_flow.merge("bs.assets" => 1), presentation_format: "ifrs_summary"),
                                       primary: true, doc_id: "S0000001").to_a).to eq []
      end
    end

    it "付加情報の連結区分は文字列にする" do
      notices = described_class.notices(statement({ "bs.assets" => 1, "pl.summary_revenue" => 110 }, consolidation_type: :consolidated),
                                        primary: true, doc_id: "S0000001").to_a
      expect(notices.map { |notice| notice.extra[:consolidation_type] }).to eq [ "consolidated" ]
    end
  end
end
