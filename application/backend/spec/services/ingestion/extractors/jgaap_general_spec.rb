require "rails_helper"

RSpec.describe Ingestion::Extractors::JgaapGeneral do
  describe "#extract（連結・S100YQ6Y: 営業収益型）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100YQ6Y"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "売上高でなく営業収益・営業原価のペアで抽出する" do
      expect(items["pl.revenue"]).to eq 10_715_342_000_000       # OperatingRevenue1（NetSalesは9,355,439百万）
      expect(items["pl.cost_of_sales"]).to eq 6_804_966_000_000  # OperatingCost（CostOfSalesは6,706,260百万）
    end

    it "営業収益 - 営業原価 - 販管費 = 営業利益 が成立する（丸め誤差の範囲）" do
      debit = items["pl.cost_of_sales"] + items["pl.sga"] + items["pl.operating_profit"]
      expect(debit).to be_within(2_000_000).of(items["pl.revenue"])
    end
  end

  describe "#extract（単体・S100YR8L: 売上原価を当期製品製造原価で開示）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100YR8L"),
                          Ingestion::Extractors::Base::NON_CONSOLIDATED).extract
    end

    it "CostOfProductsManufacturedフォールバックで原価が取れる" do
      expect(items["pl.revenue"]).to eq 2_478_950_000
      expect(items["pl.cost_of_sales"]).to eq 1_621_713_000
    end

    it "売上 - 原価 - 販管費 = 営業利益 が成立する（丸め誤差の範囲）" do
      debit = items["pl.cost_of_sales"] + items["pl.sga"] + items["pl.operating_profit"]
      expect(debit).to be_within(2_000).of(items["pl.revenue"])
    end
  end
end
