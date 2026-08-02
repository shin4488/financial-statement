require "rails_helper"

RSpec.describe Ingestion::FormatDetector do
  subject(:detector) { described_class.new }

  # FormatDetectorがxbrlに要求するのはmoneyだけなので最小のスタブで足りる
  def xbrl_with_current_assets(present:)
    instance_double(Xbrl::Document).tap do |xbrl|
      allow(xbrl).to receive(:money)
        .with("jpigp_cor:CurrentAssetsIFRS", anything)
        .and_return(present ? 1_000 : nil)
    end
  end

  describe "日本基準" do
    it "業種DEIなし・cteは一般、bnkは銀行になる" do
      aggregate_failures do
        [nil, "", "cte", "CTE"].each do |industry|
          expect(detector.detect(nil, accounting_standard: "japan_gaap",
                                 industry_code: industry, consolidation: "")).to eq "jgaap_general"
        end
        %w[bnk BNK].each do |industry|
          expect(detector.detect(nil, accounting_standard: "japan_gaap",
                                 industry_code: industry, consolidation: "")).to eq "jgaap_bank"
        end
      end
    end

    it "未知の業種は安全側でunsupportedになる" do
      expect(detector.detect(nil, accounting_standard: "japan_gaap",
                             industry_code: "ins", consolidation: "")).to eq "unsupported"
    end
  end

  describe "IFRS" do
    it "流動資産タグが実在すればclassified、なければliquidity" do
      expect(detector.detect(xbrl_with_current_assets(present: true),
                             accounting_standard: "ifrs", industry_code: "cte",
                             consolidation: "")).to eq "ifrs_classified"
      expect(detector.detect(xbrl_with_current_assets(present: false),
                             accounting_standard: "ifrs", industry_code: "INS",
                             consolidation: "")).to eq "ifrs_liquidity"
    end
  end

  it "US GAAPはunsupportedになる" do
    expect(detector.detect(nil, accounting_standard: "us_gaap",
                           industry_code: nil, consolidation: "")).to eq "unsupported"
  end
end
