require "rails_helper"

RSpec.describe Ingestion::Extractors::JgaapBank do
  describe "#extract（連結・S100YJQO）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100YJQO"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "銀行の骨格科目を期待値どおり抽出する" do
      expect(items).to include(
        "bs.assets" => 431_731_548_000_000,
        "bs.equity" => 23_744_152_000_000,
        "bs.loans" => 133_799_490_000_000,
        "bs.deposits" => 239_439_246_000_000,
        "pl.ordinary_revenue" => 14_620_843_000_000,
        "pl.ordinary_profit" => 3_410_192_000_000,
        "cf.operating" => -23_064_420_000_000,
      )
    end

    it "売上高（pl.revenue）は保存しない（銀行のトップラインは経常収益）" do
      expect(items).not_to have_key("pl.revenue")
    end
  end
end
