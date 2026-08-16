# sidekiq-cron（config/sidekiq-cron.yml）から日次起動されるジョブ。
# 過去期間の手動実行は rake ingestion:backfill を使う（同じ経路・冪等）
class DailyIngestionJob < ApplicationJob
  def perform = Ingestion::DailyIngestionService.run
end
