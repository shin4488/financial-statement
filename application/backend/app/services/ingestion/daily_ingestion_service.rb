module Ingestion
  # 日次実行のエントリポイント（バックフィルにも同じ経路を使う）
  class DailyIngestionService
    # 書類間に挟む待ち時間（秒）。EDINETはリクエスト過多で403を返すため、
    # バックフィルのような連続実行でもレート制限に当たらないよう最低限の間隔を空ける
    THROTTLE_SECONDS = 1

    # デフォルトが当日でなく前日なのは、EDINETの書類一覧が提出日単位で、
    # ジョブ実行時刻（深夜）には当日分がまだ出そろっていないため。
    # 前日分なら1回の実行でその日の提出書類を取り切れる
    def self.run(from_date: Time.zone.yesterday, to_date: Time.zone.yesterday)
      client = Edinet::Client.new
      ingester = ReportIngester.new(client: client)
      Dir.mktmpdir("edinet") do |work_dir|
        (from_date.to_date..to_date.to_date).each do |date|
          client.list_annual_reports(date: date).each do |meta|
            # 1件の失敗を他社に波及させないため書類単位で隔離。
            # EDINETはリクエスト過多で403になるため同期・逐次実行（並列化しない）
            begin
              ingester.ingest(doc_id: meta.doc_id, work_dir: work_dir,
                              expected_sec_code: meta.sec_code)
              Rails.logger.info("ingested #{meta.doc_id} #{meta.filer_name}")
            rescue => e
              Rails.logger.error("ingest failed #{meta.doc_id}: #{e.message}")
              Sentry.with_scope do |scope|
                scope.set_tags(document_id: meta.doc_id)
                Sentry.capture_exception(e)
              end
            end
            sleep(THROTTLE_SECONDS)
          end
        rescue => e
          # 一覧取得自体の失敗も日単位で隔離する。この日の有報は取り込まれないままになるため、
          # Sentry通知を見たら該当日を rake ingestion:backfill で再実行する（全処理が冪等）。
          # 手順は docs/guide/06_development_operations.md の「日次バッチの監視とリカバリ」を参照
          Rails.logger.error("list failed #{date}: #{e.message}")
          Sentry.capture_exception(e)
        end
      end
    end
  end
end
