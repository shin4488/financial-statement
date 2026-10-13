module UseCases
  # 書類を1件ずつ順に処理する実行部（日次取込とrakeの共通）。
  # 1件の失敗を他に波及させないため書類単位で隔離する。
  # EDINETはリクエスト過多で403になるため同期・逐次実行（並列化しない）
  module SequentialRunner
    # 書類間に挟む待ち時間（秒）。バックフィルのような連続実行でもレート制限に当たらないよう最低限の間隔を空ける
    THROTTLE_SECONDS = 1

    module_function

    # 記録の仕方（on_success・on_failure）と待ち方（sleeper）は呼び出し側が渡す。
    # 待つ秒数は呼び出し側に選ばせず、ここで決める
    def each(items, sleeper:, on_success:, on_failure:)
      items.each do |item|
        begin
          yield item
          on_success.call(item)
        rescue => e
          on_failure.call(item, e)
        end
        sleeper.call(THROTTLE_SECONDS)
      end
    end
  end
end
