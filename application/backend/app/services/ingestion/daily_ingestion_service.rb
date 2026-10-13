module Ingestion
  # 日次実行のエントリポイント（バックフィルにも同じ経路を使う）
  class DailyIngestionService
    # SequentialRunner::THROTTLE_SECONDS と同じ値。書類間の待ち時間はそちらで決まり、この定数を変えても変わらない
    THROTTLE_SECONDS = UseCases::SequentialRunner::THROTTLE_SECONDS

    # 待ち方には自分の sleep を渡す。このクラスの sleep を差し替えると、書類間の待ち時間を記録・省略できる
    def self.run(**dates)
      UseCases::IngestFilings.new(sleeper: ->(seconds) { sleep(seconds) }).call(**dates)
    end
  end
end
