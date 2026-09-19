require "rails_helper"

RSpec.describe Ingestion::Extractors::IfrsSummary do
  describe "#extract（連結・S100SO41: 詳細タグ付け義務化前の有報）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100SO41"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "経営指標サマリからPL・CFと指標用の利益・期首期末残高を抽出する" do
      expect(items).to eq(
        "bs.assets" => 72_459_000_000,
        "bs.assets_begin" => 71_409_000_000,
        "bs.equity_attributable_to_owners" => 18_706_000_000,
        "bs.equity_attributable_to_owners_begin" => 18_036_000_000,
        "pl.profit_attributable_to_owners" => 1_321_000_000,
        "pl.revenue" => 119_281_000_000,
        "pl.profit_before_tax" => 3_688_000_000,
        "cf.operating" => 8_364_000_000,
        "cf.investing" => -4_886_000_000,
        "cf.financing" => -2_900_000_000,
        "cf.cash_begin" => 12_665_000_000,
        "cf.cash_end" => 13_248_000_000)
    end
  end
end
