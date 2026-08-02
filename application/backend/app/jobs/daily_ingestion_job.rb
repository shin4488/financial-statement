# sidekiq-cron から起動する想定のジョブ。
# cron登録は切替判断のタイミングまで行わない（SecurityReportSubscriberJobと並走させると
# EDINETへのリクエストが倍になるため）。手動実行は rake ingestion:backfill を使う
class DailyIngestionJob < ApplicationJob
  def perform = Ingestion::DailyIngestionService.run
end
