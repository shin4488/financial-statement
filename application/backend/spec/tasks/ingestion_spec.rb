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

    ingest_documents = instance_double(UseCases::IngestDocuments)
    expect(UseCases::IngestDocuments).to receive(:new).with(no_args).and_return(ingest_documents)
    expect(ingest_documents).to receive(:call).with(match_array([
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
    ingest_documents = instance_double(UseCases::IngestDocuments)
    expect(UseCases::IngestDocuments).to receive(:new).with(no_args).and_return(ingest_documents)
    expect(ingest_documents).to receive(:call).with(match_array([
      unchecked.report.edinet_document_id, unsupported.report.edinet_document_id
    ]))
    Rake::Task["ingestion:reingest_disclosed_roe"].reenable
    Rake::Task["ingestion:reingest_disclosed_roe"].invoke
  end
end

RSpec.describe "ingestion の書類を取り込むタスク" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ingestion:documents")
  end

  # EDINETへの一覧の取得・書類の取得と、書類の間の待ち時間を順に記録する
  let(:events) { [] }

  # タスクは待ち方を渡さずに取込を作るため、既定の待ち方（Kernel.sleep）を差し替えて、待った秒数を記録する
  before { allow(Kernel).to receive(:sleep) { |seconds| events << [ :sleep, seconds ] } }

  def run_task(name, *args)
    Rake::Task[name].reenable
    Rake::Task[name].invoke(*args)
  end

  # 書類はXBRLを含まないzipで返す（取込では何もしない）。failing の書類はEDINETが500を返す
  def stub_documents(failing: [])
    stub_request(:get, %r{/documents/[A-Z0-9]{8}\?}).to_return do |request|
      doc_id = request.uri.path.split("/").last
      events << [ :download, doc_id ]
      next { status: [ 500, "Internal Server Error" ] } if failing.include?(doc_id)
      zip = Zip::OutputStream.write_buffer do |stream|
        stream.put_next_entry("#{doc_id}/AuditDoc/audit.xbrl")
        stream.write("")
      end
      { status: 200, body: zip.string }
    end
  end

  def stub_lists(doc_ids_by_date)
    stub_request(:get, %r{documents\.json}).to_return do |request|
      date = request.uri.query_values["date"]
      events << [ :list, date ]
      results = doc_ids_by_date.fetch(date, []).map do |doc_id|
        { "docID" => doc_id, "secCode" => "45020", "filerName" => "テスト株式会社", "ordinanceCode" => "010", "docTypeCode" => "120" }
      end
      { status: 200, body: { "results" => results }.to_json }
    end
  end

  describe "ingestion:documents" do
    it "引数の文字列をカンマと空白で区切ったdocIDを順に取り込み、失敗した書類は出力と通知をして次へ進み、書類ごとに本番の間隔（1秒）を待つ" do
      stub_documents(failing: [ "S1000001" ])
      allow(Sentry).to receive(:capture_exception)

      expect { run_task("ingestion:documents", "S1000001,S1000002 S1000003") }.to output(<<~OUT).to_stdout
        ingest failed S1000001: 500 Internal Server Error
        ingested S1000002
        ingested S1000003
      OUT

      expect(events).to eq [ [ :download, "S1000001" ], [ :sleep, 1 ], [ :download, "S1000002" ], [ :sleep, 1 ],
                             [ :download, "S1000003" ], [ :sleep, 1 ] ]
      expect(Sentry).to have_received(:capture_exception).once
      expect(Sentry).to have_received(:capture_exception).with(having_attributes(message: "500 Internal Server Error"))
    end

    it "コマンドラインでカンマと空白で区切ったdocIDは、rakeがカンマで分けた2つ目以降も含めて、すべて順に取り込む" do
      stub_documents
      Rake::Task["ingestion:documents"].reenable

      # rake 'ingestion:documents[S1000001,S1000002 S1000003]' と同じく、rakeがコマンドラインの文字列を引数に分けてから実行する
      expect { Rake.application.invoke_task("ingestion:documents[S1000001,S1000002 S1000003]") }.to output(<<~OUT).to_stdout
        ingested S1000001
        ingested S1000002
        ingested S1000003
      OUT

      expect(events).to eq [ [ :download, "S1000001" ], [ :sleep, 1 ], [ :download, "S1000002" ], [ :sleep, 1 ],
                             [ :download, "S1000003" ], [ :sleep, 1 ] ]
    end

    it "docIDを渡さなければ、何も取り込まずに止まる" do
      stub_documents

      expect { run_task("ingestion:documents") }.to raise_error(KeyError)
      expect(events).to be_empty
    end
  end

  describe "ingestion:backfill" do
    it "開始日から終了日までの各日の一覧を順に取得し、書類ごとに本番の間隔（1秒）を待つ" do
      stub_lists("2026-06-20" => [ "S1000001" ], "2026-06-22" => [ "S1000002" ])
      stub_documents

      run_task("ingestion:backfill", "2026-06-20", "2026-06-22")

      expect(events).to eq [ [ :list, "2026-06-20" ], [ :download, "S1000001" ], [ :sleep, 1 ],
                             [ :list, "2026-06-21" ],
                             [ :list, "2026-06-22" ], [ :download, "S1000002" ], [ :sleep, 1 ] ]
    end
  end

  describe "ingestion:reingest_ifrs_summary" do
    it "資産合計のない主のifrs_liquidityの有報だけを、提出日の順に再取込する" do
      later = create(:disclosure_financial_statement, presentation_format: "ifrs_liquidity",
                     report: create(:disclosure_report, filing_date: Date.new(2026, 6, 25)),
                     items_hash: { "bs.cash_and_equivalents" => 100 })
      earlier = create(:disclosure_financial_statement, presentation_format: "ifrs_liquidity",
                       report: create(:disclosure_report, filing_date: Date.new(2026, 6, 20)))
      create(:disclosure_financial_statement, presentation_format: "ifrs_liquidity", items_hash: { "bs.assets" => 1_000 })
      create(:disclosure_financial_statement, presentation_format: "ifrs_liquidity", is_primary: false)
      create(:disclosure_financial_statement, presentation_format: "ifrs_summary")
      stub_documents
      targets = [ earlier, later ].map { |statement| statement.report.edinet_document_id }

      expect { run_task("ingestion:reingest_ifrs_summary") }.to output(<<~OUT).to_stdout
        reingest 2 documents
        ingested #{targets[0]}
        ingested #{targets[1]}
      OUT

      expect(events).to eq [ [ :download, targets[0] ], [ :sleep, 1 ], [ :download, targets[1] ], [ :sleep, 1 ] ]
    end
  end

  describe "ingestion:reingest_unsupported" do
    it "unsupportedの財務諸表を含む有報（主でない財務諸表を含む）のうち、提出日が範囲内（両端を含む）の有報を一度ずつ提出日の順に再取込する" do
      first_day = create(:disclosure_report, filing_date: Date.new(2026, 6, 1))
      create(:disclosure_financial_statement, report: first_day, presentation_format: "unsupported")
      create(:disclosure_financial_statement, report: first_day, presentation_format: "unsupported",
             consolidation_type: :non_consolidated, is_primary: false)
      secondary = create(:disclosure_report, filing_date: Date.new(2026, 6, 20))
      create(:disclosure_financial_statement, report: secondary, presentation_format: "jgaap_general", accounting_standard: :japan_gaap)
      create(:disclosure_financial_statement, report: secondary, presentation_format: "unsupported",
             consolidation_type: :non_consolidated, is_primary: false)
      last_day = create(:disclosure_report, filing_date: Date.new(2026, 6, 30))
      create(:disclosure_financial_statement, report: last_day, presentation_format: "unsupported")
      [ Date.new(2026, 5, 31), Date.new(2026, 7, 1) ].each do |outside|
        create(:disclosure_financial_statement, report: create(:disclosure_report, filing_date: outside),
               presentation_format: "unsupported")
      end
      create(:disclosure_financial_statement, report: create(:disclosure_report, filing_date: Date.new(2026, 6, 15)))
      stub_documents
      targets = [ first_day, secondary, last_day ].map(&:edinet_document_id)

      expect { run_task("ingestion:reingest_unsupported", "2026-06-01", "2026-06-30") }.to output(<<~OUT).to_stdout
        reingest 3 documents (filing_date 2026-06-01..2026-06-30)
        ingested #{targets[0]}
        ingested #{targets[1]}
        ingested #{targets[2]}
      OUT

      expect(events).to eq targets.flat_map { |doc_id| [ [ :download, doc_id ], [ :sleep, 1 ] ] }
    end
  end
end
