require "rails_helper"

RSpec.describe Ingestion::FormatRegistry do
  let(:formats) { FinancialStatements::Formats }

  it "unsupported以外のすべての形式にExtractorがある" do
    expect(described_class::EXTRACTORS.keys).to match_array(formats::ALL - [ formats::UNSUPPORTED ])
    expect(described_class.extractor_for(formats::UNSUPPORTED)).to be_nil
  end

  it "形式名と一覧は、FinancialStatements::Formats と同じ値を指す" do
    expect(described_class::ALL).to equal formats::ALL
    (formats.constants - [ :ALL ]).each do |name|
      expect(described_class.const_get(name)).to equal formats.const_get(name)
    end
  end
end
