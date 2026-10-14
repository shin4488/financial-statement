# 先読みが外れて、件数に比例した問い合わせが出ていないかを確かめるため、SQLの回数を数える
module QueryCounter
  # ブロックの中で出たSQLの回数。スキーマの読み込みと、クエリキャッシュが返したものは数えない
  def count_queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end

RSpec.configure { |config| config.include QueryCounter }
