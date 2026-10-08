require "rails_helper"

RSpec.describe Ingestion::Reconciliation do
  describe "CFの照合" do
    # 期首残＋営業CF＋投資CF＋財務CF＝期末残が、換算差額の分（10）だけ合わないCF
    let(:items) do
      FinancialStatements::Amounts.new.merge!(
        "cf.cash_begin" => 100, "cf.operating" => 50, "cf.investing" => -30, "cf.financing" => -20, "cf.cash_end" => 110)
    end

    def cash_flow_warnings(format) = described_class.warnings(items, format).select { |w| w.message.start_with?("cash flow") }

    it "換算差額などの行を読む形式は、式が合わなければ照合に使った金額を付けて警告する" do
      expect(cash_flow_warnings("jgaap_general")).to eq [
        described_class::Warning.new("cash flow does not reconcile with closing balance",
                                     items.to_h)
      ]
    end

    it "経営指標の要約だけで作る形式は、換算差額などの行がないため照合しない" do
      aggregate_failures do
        expect(cash_flow_warnings("ifrs_summary")).to be_empty
        expect(cash_flow_warnings("usgaap_summary")).to be_empty
      end
    end
  end
end
