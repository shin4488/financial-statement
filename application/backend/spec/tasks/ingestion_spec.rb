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
