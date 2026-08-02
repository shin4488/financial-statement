require "rails_helper"

RSpec.describe Charts::BuilderRegistry do
  it "FormatRegistryの全形式（unsupported以外）にBS/PLのBuilderが対応している" do
    supported = Ingestion::FormatRegistry::ALL - [Ingestion::FormatRegistry::UNSUPPORTED]
    expect(described_class::BS.keys).to match_array(supported)
    expect(described_class::PL.keys).to match_array(supported)
  end

  it "unsupported形式はBS/PLがunrenderableになり、CFは科目があれば描ける" do
    fs = build(:disclosure_financial_statement, presentation_format: "unsupported")
    allow(fs).to receive(:items_hash).and_return(
      { "cf.cash_begin" => 1, "cf.operating" => 2, "cf.investing" => 3,
        "cf.financing" => 4, "cf.cash_end" => 10 })
    charts = described_class.build_all(fs)
    expect(charts[:balance_sheet].renderable).to be false
    expect(charts[:profit_loss].renderable).to be false
    expect(charts[:cash_flow].renderable).to be true
  end
end
