require "rails_helper"

RSpec.describe "実書類の報告期間に基づく取込" do
  {
    "S100YYOW" => { revenue: 3_803_000_000, cash_begin: 11_833_000_000, roe: "0.0495" },
    "S100YYT8" => { revenue: 58_471_441_000, cash_begin: 5_243_779_000, roe: "0.112" }
  }.each do |doc_id, expected|
    it "#{doc_id}の連結期間を単体のDEI開始日で切り詰めず、損益・CF・公表ROEを保存する" do
      require_xbrl_fixture(doc_id)
      Dir.mktmpdir do |dir|
        Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: doc_id, work_dir: dir)
      end
      report = Disclosure::Report.find_by!(edinet_document_id: doc_id)
      expect(report.fiscal_year_start_date.to_s).to eq "2025-12-01"
      consolidated = report.primary_financial_statement
      expect(consolidated.items_hash).to include("pl.revenue" => expected[:revenue], "cf.cash_begin" => expected[:cash_begin])
      expect(consolidated.disclosed_roe).to eq expected[:roe].to_d
    end
  end

  it "S100Z0VFの実際の年度で連結・単体を保存し、再取込しても三表と公表ROEを保持する", :aggregate_failures do
    require_xbrl_fixture("S100Z0VF")
    Dir.mktmpdir do |dir|
      2.times { Ingestion::ReportIngester.new(client: FixtureEdinetClient.new).ingest(doc_id: "S100Z0VF", work_dir: dir) }
    end
    report = Disclosure::Report.find_by!(edinet_document_id: "S100Z0VF")
    consolidated = report.primary_financial_statement
    single = report.financial_statements.find_by!(consolidation_type: :non_consolidated)
    expect(report.fiscal_year_start_date.to_s).to eq "2025-01-01"
    expect(report.fiscal_year_end_date.to_s).to eq "2025-12-31"
    expect(consolidated.items_hash).to include(
      "bs.assets" => 191_166_000_000, "pl.revenue" => 303_926_000_000,
      "pl.profit_attributable_to_owners" => 3_096_000_000, "cf.cash_begin" => 0,
      "bs.equity_attributable_to_owners" => 66_602_000_000)
    expect(consolidated.items_hash).not_to have_key("bs.assets_begin")
    expect(consolidated.disclosed_roe).to eq "0.093".to_d
    expect(single.items_hash).to include("bs.assets" => 157_557_000_000, "bs.assets_begin" => 0)
    expect(single.disclosed_roe).to eq "0.054".to_d
    expect(report.financial_statements.all? { |fs| fs.disclosed_roe_checked_at.present? }).to be true

    result = FinancialStatementSchema.execute(<<~GRAPHQL).to_h
      query { financialReports(limit: 1, offset: 0) {
        balanceSheet { renderable } profitLoss { renderable } cashFlow { renderable }
        financialIndicators { roe { value status source } roa { value status } }
      } }
    GRAPHQL
    expect(result["errors"]).to be_nil
    card = result.dig("data", "financialReports", 0)
    %w[balanceSheet profitLoss cashFlow].each { |key| expect(card.dig(key, "renderable")).to be true }
    expect(card.dig("financialIndicators", "roe")).to eq("value" => 0.093, "status" => "AVAILABLE", "source" => "DISCLOSED")
    expect(card.dig("financialIndicators", "roa")).to eq("value" => nil, "status" => "MISSING_DATA")
  end
end
