require "rails_helper"

RSpec.describe Ingestion::Extractors::IfrsLiquidity do
  describe "#extract（連結・S100XTNW: 流動性配列 + 営業費用一括）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100XTNW"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "合計科目と営業費用一括を実測値どおり抽出する" do
      expect(items).to include(
        "bs.assets" => 28_804_400_000_000,
        "bs.equity" => 1_354_232_000_000,
        "pl.revenue" => 2_496_575_000_000,
        "pl.profit_before_tax" => -29_550_000_000,
        "cf.operating" => 424_093_000_000,
      )
      expect(items).to have_key("pl.operating_expenses")
    end

    it "流動/非流動の分類系コードは存在しない" do
      expect(items.keys.grep(/current/)).to be_empty
    end
  end

  describe "#extract（連結・S100YLS8: 収益が標準タグにない保険IFRS）" do
    it "pl.revenueは取れないがBS・CFは取れる（PL表示不可の正常系）" do
      items = described_class.new(load_xbrl_fixture("S100YLS8"),
                                  Ingestion::Extractors::Base::CONSOLIDATED).extract
      expect(items).not_to have_key("pl.revenue")
      expect(items["bs.assets"]).to eq 33_002_651_000_000
      expect(items["pl.profit_before_tax"]).to eq 750_700_000_000
      expect(items["cf.operating"]).to eq 1_390_562_000_000
    end
  end
end
