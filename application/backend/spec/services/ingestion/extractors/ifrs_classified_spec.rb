require "rails_helper"

RSpec.describe Ingestion::Extractors::IfrsClassified do
  describe "#extract（連結・S100YB5L: 税引前損失 + のれん別掲）" do
    subject(:items) do
      described_class.new(load_xbrl_fixture("S100YB5L"),
                          Ingestion::Extractors::Base::CONSOLIDATED).extract
    end

    it "BS/PL/CFの骨格科目を期待値どおり抽出する" do
      expect(items).to include(
        "bs.assets" => 15_511_506_000_000,
        "bs.equity" => 7_430_649_000_000,
        "pl.revenue" => 4_505_720_000_000,
        "pl.profit_before_tax" => -142_355_000_000,
        "cf.operating" => 1_041_431_000_000,
        "cf.cash_begin" => 385_113_000_000,
      )
    end

    it "別掲されたのれんと無形資産を合算する" do
      expect(items["bs.goodwill_and_intangibles"]).to eq 5_809_010_000_000 + 3_419_348_000_000
    end

    it "非開示の科目はキー自体を作らない" do
      expect(items).not_to have_key("pl.gross_profit")       # 売上総利益は非開示
      expect(items).not_to have_key("pl.operating_expenses") # 営業費用一括型でもない
    end
  end

  describe "#extract（連結・S100YCP3: 収益が企業拡張タグの企業）" do
    it "経営指標サマリへのフォールバックで収益が取れる" do
      items = described_class.new(load_xbrl_fixture("S100YCP3"),
                                  Ingestion::Extractors::Base::CONSOLIDATED).extract
      expect(items["pl.revenue"]).to eq 14_409_121_000_000
    end
  end

  describe "#extract（連結・S100YB25: 合算のれんタグ + Revenue2IFRS）" do
    it "収益がRevenue2IFRSフォールバックで取れ、資産が一致する" do
      items = described_class.new(load_xbrl_fixture("S100YB25"),
                                  Ingestion::Extractors::Base::CONSOLIDATED).extract
      expect(items["bs.assets"]).to eq 24_151_695_000_000
      expect(items["pl.revenue"]).to eq 18_915_995_000_000
    end
  end
end
