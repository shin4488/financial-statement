# rails cの手打ちにしない理由: 長時間ジョブは中断・再開が前提になるため、
# コマンド1つで任意期間を再実行できる形にしておく（全処理が冪等のため重複実行は無害）
module IngestionTasks
  # docID列を上から順に取り込む（このファイルの全タスク共通の実行部）。
  # 1件の失敗を他に波及させない（日次取込と同じ方針）。失敗分は出力を見て個別に再実行する
  def self.ingest_each(doc_ids)
    ingester = Ingestion::ReportIngester.new
    Dir.mktmpdir("edinet") do |work_dir|
      doc_ids.each do |doc_id|
        begin
          ingester.ingest(doc_id: doc_id, work_dir: work_dir)
          puts "ingested #{doc_id}"
        rescue => e
          puts "ingest failed #{doc_id}: #{e.message}"
          Sentry.capture_exception(e)
        end
        sleep(Ingestion::DailyIngestionService::THROTTLE_SECONDS) # EDINETのレート制限（403）対策
      end
    end
  end
end

namespace :ingestion do
  desc "指定期間の有報をEDINETから取り込む 例: rake 'ingestion:backfill[2025-01-01,2025-12-31]'"
  task :backfill, [ :from, :to ] => :environment do |_, args|
    from = Date.parse(args.fetch(:from))
    to = Date.parse(args.fetch(:to))
    # 日付・docIDはRails.loggerに出る。中断したらログの最終日付から再実行すればよい
    Ingestion::DailyIngestionService.run(from_date: from, to_date: to)
  end

  desc "docID指定で有報を取り込む 例: rake 'ingestion:documents[S100YB5L S100YB25]'"
  task :documents, [ :doc_ids ] => :environment do |_, args|
    IngestionTasks.ingest_each(args.fetch(:doc_ids).split(/[,\s]+/))
  end

  # ifrs_summary形式の追加前に取り込まれ、詳細タグの無い有報が ifrs_liquidity として
  # 保存されている既存データを取り直すためのタスク。対象を「primaryなのに資産合計が無い」に
  # 絞るのは、正しく ifrs_liquidity と判定された有報を再取込せず EDINETへのリクエストを
  # 最小にするため（移行完了後は対象0件になり、再実行しても何もしない）
  desc "BSが取れていないifrs_liquidityの有報を再取込する（ifrs_summaryへの移行）"
  task reingest_ifrs_summary: :environment do
    target_statements = Disclosure::FinancialStatement
                          .where(presentation_format: Ingestion::FormatRegistry::IFRS_LIQUIDITY,
                                 is_primary: true)
                          .where.not(id: Disclosure::FinancialStatementItem
                                           .where(item_code: "bs.assets")
                                           .select(:financial_statement_id))
    doc_ids = Disclosure::Report.where(id: target_statements.select(:report_id))
                                .order(:filing_date).pluck(:edinet_document_id)
    puts "reingest #{doc_ids.size} documents"
    IngestionTasks.ingest_each(doc_ids)
  end

  # 新しい形式（業種）に対応したあと、既に unsupported で保存済みの有報を取り直すためのタスク。
  # 対象を unsupported に絞るのは、全期間のバックフィルより EDINET へのリクエストが桁違いに少なくて済むため
  desc "unsupported判定の財務諸表を含む有報（提出日の範囲指定）を再取込する 例: rake 'ingestion:reingest_unsupported[2025-08-01,2026-08-16]'"
  task :reingest_unsupported, [ :from, :to ] => :environment do |_, args|
    from = Date.parse(args.fetch(:from))
    to = Date.parse(args.fetch(:to))
    unsupported_report_ids = Disclosure::FinancialStatement
                               .where(presentation_format: Ingestion::FormatRegistry::UNSUPPORTED)
                               .select(:report_id)
    doc_ids = Disclosure::Report.where(id: unsupported_report_ids, filing_date: from..to)
                                .order(:filing_date).pluck(:edinet_document_id)
    puts "reingest #{doc_ids.size} documents (filing_date #{from}..#{to})"
    IngestionTasks.ingest_each(doc_ids)
  end
end
