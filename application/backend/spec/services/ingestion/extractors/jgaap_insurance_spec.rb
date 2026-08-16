require "rails_helper"

RSpec.describe Ingestion::Extractors::JgaapInsurance do
  describe "#extract（連結・S100YD29 かんぽ生命）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100YD29"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "保険の骨格科目を期待値どおり抽出する（単位: 円）" do
      expect(items).to include(
        "bs.assets" => 58_442_160_000_000,
        "bs.cash_and_equivalents" => 1_752_984_000_000, # 現金及び預貯金
        "bs.securities" => 44_931_286_000_000,
        "bs.loans" => 2_134_764_000_000,                # 貸付金
        "bs.policy_reserves" => 48_102_350_000_000,     # 保険契約準備金
        "bs.equity" => 4_153_628_000_000,
        "pl.ordinary_revenue" => 5_625_758_000_000,     # OperatingIncomeINS（経常収益）
        "pl.ordinary_expenses" => 5_353_811_000_000,
        "pl.ordinary_profit" => 271_946_000_000,
      )
    end

    it "売上高（pl.revenue）は保存しない（保険のトップラインは経常収益）" do
      expect(items).not_to have_key("pl.revenue")
    end
  end
end
