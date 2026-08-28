require "rails_helper"

RSpec.describe Ingestion::Extractors::IfrsSummary do
  describe "#extract（連結・S100SO41: 詳細タグ付け義務化前の有報）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100SO41"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "経営指標サマリからPLの骨格とCFの5点を抽出し、BSは抽出しない" do
      expect(items).to eq(
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
