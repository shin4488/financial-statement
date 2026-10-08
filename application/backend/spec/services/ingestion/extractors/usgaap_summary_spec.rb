require "rails_helper"

RSpec.describe Ingestion::Extractors::UsgaapSummary do
  def extract(doc_id) = described_class.new(load_xbrl_fixture(doc_id), Ingestion::Extractors::Base::CONSOLIDATED).extract

  it "キヤノン 2025年12月期: 経営指標の要約から、CFと財務指標に使う残高・利益・売上を抽出する" do
    expect(extract("S100XTLJ")).to eq(
      "bs.assets" => 6_135_044_000_000,
      "bs.assets_begin" => 5_766_246_000_000,
      "bs.equity_attributable_to_owners" => 3_491_808_000_000,
      "bs.equity_attributable_to_owners_begin" => 3_380_273_000_000,
      "pl.revenue" => 4_624_727_000_000,
      "pl.profit_attributable_to_owners" => 332_053_000_000,
      "cf.operating" => 475_903_000_000,
      "cf.investing" => -237_450_000_000,
      "cf.financing" => -179_221_000_000,
      "cf.cash_begin" => 501_565_000_000,
      "cf.cash_end" => 585_981_000_000)
  end

  it "ソニー 2021年3月期: 親会社株主に帰属する持分がなければ、非支配持分を含む純資産で代えず、自己資本を保存しない" do
    items = extract("S100LM4N")
    aggregate_failures do
      expect(items.keys).not_to include("bs.equity_attributable_to_owners", "bs.equity_attributable_to_owners_begin")
      expect(items.values_at("bs.assets_begin", "bs.assets")).to eq [ 23_039_343_000_000, 26_354_840_000_000 ]
      expect(items["pl.profit_attributable_to_owners"]).to eq 1_171_776_000_000
    end
  end
end
