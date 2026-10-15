module UseCases
  # 提出日ごとの書類一覧から有報を取り込む（日次ジョブとバックフィルの経路）
  class IngestFilings
    def initialize(client: Edinet::Client.new, sleeper: Kernel.method(:sleep))
      @client, @sleeper = client, sleeper
    end

    # デフォルトが当日でなく前日なのは、EDINETの書類一覧が提出日単位で、ジョブ実行時刻（深夜）には当日分がまだ出そろっていないため。
    # 前日分なら1回の実行でその日の提出書類を取り切れる
    def call(from_date: Time.zone.yesterday, to_date: Time.zone.yesterday)
      ingest_report = IngestReport.new(client: @client)
      Dir.mktmpdir("edinet") do |work_dir|
        (from_date.to_date..to_date.to_date).each do |date|
          SequentialRunner.each(@client.list_annual_reports(date: date), sleeper: @sleeper,
                                on_success: method(:record_success), on_failure: method(:record_failure)) do |meta|
            ingest_report.call(doc_id: meta.doc_id, work_dir: work_dir, expected_sec_code: meta.sec_code)
          end
        rescue => e
          # 一覧取得自体の失敗も日単位で隔離する。
          # この日の有報は取り込まれないままになるため、Sentry通知を見たら該当日を rake ingestion:backfill で再実行する（全処理が冪等）。
          Rails.logger.error("list failed #{date}: #{e.message}")
          Sentry.capture_exception(e)
        end
      end
    end

    private

    def record_success(meta) = Rails.logger.info("ingested #{meta.doc_id} #{meta.filer_name}")

    def record_failure(meta, error)
      Rails.logger.error("ingest failed #{meta.doc_id}: #{error.message}")
      Sentry.with_scope do |scope|
        scope.set_tags(document_id: meta.doc_id)
        Sentry.capture_exception(error)
      end
    end
  end
end
