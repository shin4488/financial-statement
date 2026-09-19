require "rails_helper"

RSpec.describe "シーラHD連結初年度の公表ROE" do
  it "平均残高を捏造せず、有報の公表37.2%を保存して表示する" do
    require_xbrl_fixture("S100YZFP")
    Dir.mktmpdir do |dir|
      Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: "S100YZFP", work_dir: dir)
    end
    report = Disclosure::Report.find_by!(edinet_document_id: "S100YZFP")
    fs = report.primary_financial_statement
    expect(fs.disclosed_roe).to eq 0.372.to_d
    expect(fs.items_hash["bs.assets_begin"]).to be_nil
    expect(fs.items_hash["bs.equity_attributable_to_owners_begin"]).to be_nil
    metrics = FinancialStatements::Indicators.build(fs)
    expect(metrics[:roe].value).to eq 0.372
    expect(metrics[:roe].source).to eq "disclosed"
    expect(metrics[:roa].status).to eq "missing_data"
    expect(metrics[:financial_leverage].status).to eq "missing_data"
    expect(report.financial_statements.find_by!(consolidation_type: :non_consolidated).disclosed_roe).to eq 0.029.to_d
  end
end
