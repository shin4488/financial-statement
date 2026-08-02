# rails cの手打ちにしない理由: 長時間ジョブは中断・再開が前提になるため、
# コマンド1つで任意期間を再実行できる形にしておく（全処理が冪等のため重複実行は無害）
namespace :ingestion do
  desc "指定期間の有報をEDINETから取り込む 例: rake 'ingestion:backfill[2025-01-01,2025-12-31]'"
  task :backfill, [:from, :to] => :environment do |_, args|
    from = Date.parse(args.fetch(:from))
    to = Date.parse(args.fetch(:to))
    # 日付・docIDはRails.loggerに出る。中断したらログの最終日付から再実行すればよい
    Ingestion::DailyIngestionService.run(from_date: from, to_date: to)
  end

  desc "docID指定で有報を取り込む 例: rake 'ingestion:documents[S100YB5L S100YB25]'"
  task :documents, [:doc_ids] => :environment do |_, args|
    ingester = Ingestion::ReportIngester.new
    Dir.mktmpdir("edinet") do |work_dir|
      args.fetch(:doc_ids).split(/[,\s]+/).each do |doc_id|
        ingester.ingest(doc_id: doc_id, work_dir: work_dir)
        puts "ingested #{doc_id}"
      end
    end
  end
end
