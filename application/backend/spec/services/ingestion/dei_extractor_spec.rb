require "rails_helper"

RSpec.describe Ingestion::DeiExtractor do
  subject(:extractor) { described_class.new }

  it "企業情報・会計期間・業種コードをDEIから取り出す" do
    dei = extractor.extract(synthetic_xbrl_document(
      dei: { consolidated_industry_code: "bnk", non_consolidated_industry_code: "cte" }))
    aggregate_failures do
      expect(dei.edinet_code).to eq "E00001"
      expect(dei.stock_code).to eq "45020" # 5桁のまま（4桁化は表示層の責務）
      expect(dei.fiscal_year_start_date).to eq "2025-04-01"
      expect(dei.fiscal_year_end_date).to eq "2026-03-31"
      expect(dei.consolidated_industry_code).to eq "bnk"
      expect(dei.non_consolidated_industry_code).to eq "cte"
    end
  end

  it "会計基準はDEIの表記から内部値へ変換し、未知の表記はnil（取込側でスキップさせる）" do
    aggregate_failures do
      { "Japan GAAP" => "japan_gaap", "US GAAP" => "us_gaap", "IFRS" => "ifrs", "その他" => nil }.each do |raw, expected|
        dei = extractor.extract(synthetic_xbrl_document(dei: { accounting_standard: raw }))
        expect(dei.accounting_standard).to eq expected
      end
    end
  end

  it "連結有無はxs:booleanの2表記（true / 1）のどちらでも真になる" do
    aggregate_failures do
      { "true" => true, "1" => true, "false" => false, "0" => false }.each do |raw, expected|
        dei = extractor.extract(synthetic_xbrl_document(dei: { has_consolidated: raw }))
        expect(dei.has_consolidated).to be expected
      end
    end
  end

  it "企業名は表紙を優先し、表紙タグがない書類はDEIの提出者名にフォールバックする" do
    with_cover = synthetic_xbrl_document(
      dei: { name_ja: "提出者名" },
      facts: { [ "jpcrp_cor:CompanyNameCoverPage", "FilingDateInstant" ] => "表紙の名前" })
    aggregate_failures do
      expect(extractor.extract(with_cover).name_ja).to eq "表紙の名前"
      expect(extractor.extract(synthetic_xbrl_document(dei: { name_ja: "提出者名" })).name_ja).to eq "提出者名"
    end
  end

  it "企業名の全角英数字・スペース・アンパサンドは半角に正規化される" do
    dei = extractor.extract(synthetic_xbrl_document(dei: { name_ja: "ＡＢＣ商事　＆　Ｄ１株式会社" }))
    expect(dei.name_ja).to eq "ABC商事 & D1株式会社"
  end
end
