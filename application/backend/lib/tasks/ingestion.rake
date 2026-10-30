# rails cの手打ちにしない理由: 長時間ジョブは中断・再開が前提になるため、
# コマンド1つで任意期間を再実行できる形にしておく（全処理が冪等のため重複実行は無害）
namespace :ingestion do
  desc "指定期間の有報をEDINETから取り込む 例: rake 'ingestion:backfill[2025-01-01,2025-12-31]'"
  task :backfill, [ :from, :to ] => :environment do |_, args|
    from = Date.parse(args.fetch(:from))
    to = Date.parse(args.fetch(:to))
    # Rails.loggerには書類ごとのdocIDが出る（日付が出るのは一覧の取得に失敗した日だけ）。
    # 中断したら、最後に出たdocIDの書類の提出日から再実行すればよい
    UseCases::IngestFilings.new.call(from_date: from, to_date: to)
  end

  desc "docID指定で有報を取り込む 例: rake 'ingestion:documents[S100YB5L S100YB25]'"
  task :documents, [ :doc_ids ] => :environment do |_, args|
    # rakeはコマンドラインの引数をカンマで分けるため、カンマで区切ったdocIDの2つ目以降は args.extras に入る
    doc_ids = [ args.fetch(:doc_ids), *args.extras ].join(",").split(/[,\s]+/)
    UseCases::IngestDocuments.new.call(doc_ids)
  end

  desc "ROE・ROA用の期首残高・自己資本が不足する既存有報を再取込する"
  task reingest_indicators: :environment do
    doc_ids = Disclosure::ReingestTargets.indicators
    puts "reingest #{doc_ids.size} documents"
    UseCases::IngestDocuments.new.call(doc_ids)
  end

  desc "企業公表ROEが未抽出の既存有報を再取込する（未開示も確認済みとして記録）"
  task reingest_disclosed_roe: :environment do
    doc_ids = Disclosure::ReingestTargets.disclosed_roe
    puts "reingest #{doc_ids.size} documents"
    UseCases::IngestDocuments.new.call(doc_ids)
  end

  desc "BSが取れていないifrs_liquidityの有報を再取込する（ifrs_summaryへの移行）"
  task reingest_ifrs_summary: :environment do
    doc_ids = Disclosure::ReingestTargets.ifrs_summary
    puts "reingest #{doc_ids.size} documents"
    UseCases::IngestDocuments.new.call(doc_ids)
  end

  desc "連結に貸借対照表だけがあるのに連結を主にしている有報を再取込する（単体を主にする）"
  task reingest_balance_sheet_only_consolidated: :environment do
    doc_ids = Disclosure::ReingestTargets.balance_sheet_only_consolidated
    puts "reingest #{doc_ids.size} documents"
    UseCases::IngestDocuments.new.call(doc_ids)
  end

  desc "unsupported判定の財務諸表を含む有報（提出日の範囲指定）を再取込する 例: rake 'ingestion:reingest_unsupported[2025-08-01,2026-08-16]'"
  task :reingest_unsupported, [ :from, :to ] => :environment do |_, args|
    from = Date.parse(args.fetch(:from))
    to = Date.parse(args.fetch(:to))
    doc_ids = Disclosure::ReingestTargets.unsupported(from, to)
    puts "reingest #{doc_ids.size} documents (filing_date #{from}..#{to})"
    UseCases::IngestDocuments.new.call(doc_ids)
  end
end
