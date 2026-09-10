require "rails_helper"

RSpec.describe "開示精度の保存" do
  it "取込とDB再読込を経ても金額と開示精度を保持する" do
    require_xbrl_fixture("S100YD29")
    Dir.mktmpdir do |dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: "S100YD29", work_dir: dir)
    end
    fs = Disclosure::FinancialStatement.find_by!(consolidation_type: :consolidated)
    amounts = fs.reload.items_hash
    expect(amounts["bs.assets"]).to eq 58_442_160_000_000
    expect(amounts.rounding_errors["bs.assets"]).to eq 1_000_000
  end
end
