require "rails_helper"

RSpec.describe Ingestion::DisclosedRoeExtractor do
  it "IFRS移行期の日本基準併記・前期・単体の値を取り違えない" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration" ] => "0.1868",
      [ "jpcrp_cor:RateOfReturnOnEquityIFRSSummaryOfBusinessResults", "CurrentYearDuration" ] => "0.0706",
      [ "jpcrp_cor:RateOfReturnOnEquityIFRSSummaryOfBusinessResults", "Prior1YearDuration" ] => "0.0617",
      [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration_NonConsolidatedMember" ] => "0.2545"
    })
    expect(described_class.extract(xbrl, accounting_standard: "ifrs", consolidation: "")).to eq 0.0706.to_d
    expect(described_class.extract(xbrl, accounting_standard: "japan_gaap", consolidation: "_NonConsolidatedMember")).to eq 0.2545.to_d
  end

  [ "", "abc", "NaN", "Infinity", "1e999" ].each do |value|
    it "空・不正・非有限の公表値#{value.inspect}をゼロにしない" do
      xbrl = synthetic_xbrl_document(facts: {
        [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration" ] => value
      })
      expect(described_class.extract(xbrl, accounting_standard: "japan_gaap", consolidation: "")).to be_nil
    end
  end

  it "対象基準で未開示なら他基準の値で代用しない" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jpcrp_cor:RateOfReturnOnEquitySummaryOfBusinessResults", "CurrentYearDuration" ] => "0.12"
    })
    expect(described_class.extract(xbrl, accounting_standard: "ifrs", consolidation: "")).to be_nil
  end

  it "米国基準は本表未対応でも公表値を取得できる" do
    xbrl = synthetic_xbrl_document(facts: {
      [ "jpcrp_cor:RateOfReturnOnEquityUSGAAPSummaryOfBusinessResults", "CurrentYearDuration" ] => "-0.1234"
    })
    expect(described_class.extract(xbrl, accounting_standard: "us_gaap", consolidation: "")).to eq(-0.1234.to_d)
  end
end
