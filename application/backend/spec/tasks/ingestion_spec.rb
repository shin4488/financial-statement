require "rails_helper"
require "rake"

RSpec.describe "ingestion:reingest_indicators" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ingestion:reingest_indicators")
  end

  it "不足する有報だけを選び、完備・非表示・未対応形式の有報は再取得しない" do
    complete_items = {
      "bs.assets_begin" => 1_000,
      "bs.equity_attributable_to_owners" => 600,
      "bs.equity_attributable_to_owners_begin" => 400
    }
    legacy = create(:disclosure_financial_statement, items_hash: { "bs.assets" => 1_500 })
    partial = create(:disclosure_financial_statement, items_hash: complete_items.except("bs.equity_attributable_to_owners_begin"))
    create(:disclosure_financial_statement, items_hash: complete_items)
    create(:disclosure_financial_statement, is_primary: false)
    create(:disclosure_financial_statement, presentation_format: "unsupported")

    expect(IngestionTasks).to receive(:ingest_each).with(match_array([
      legacy.report.edinet_document_id, partial.report.edinet_document_id
    ]))
    Rake::Task["ingestion:reingest_indicators"].reenable
    Rake::Task["ingestion:reingest_indicators"].invoke
  end
end

RSpec.describe "ingestion:reingest_disclosed_roe" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ingestion:reingest_disclosed_roe")
  end

  it "計算可否・形式によらず未確認有報を一度ずつ選び、確認済みの未開示は除く" do
    unchecked = create(:disclosure_financial_statement)
    create(:disclosure_financial_statement, report: unchecked.report, consolidation_type: :non_consolidated, is_primary: false)
    unsupported = create(:disclosure_financial_statement, presentation_format: "unsupported")
    create(:disclosure_financial_statement, disclosed_roe: nil, disclosed_roe_checked_at: Time.current)
    create(:disclosure_financial_statement, disclosed_roe: 0.12, disclosed_roe_checked_at: Time.current)
    expect(IngestionTasks).to receive(:ingest_each).with(match_array([
      unchecked.report.edinet_document_id, unsupported.report.edinet_document_id
    ]))
    Rake::Task["ingestion:reingest_disclosed_roe"].reenable
    Rake::Task["ingestion:reingest_disclosed_roe"].invoke
  end
end
