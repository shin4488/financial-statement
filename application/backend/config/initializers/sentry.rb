
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # 本番のみ送信する: development/testはローカル作業のエラー（DB未起動・デバッグ片等）が
  # そのまま流れてノイズになるため
  config.enabled_environments = %w[production]
  # 運用スクリプトの正常終了（exit）や停止シグナル（kill・デプロイ再起動）は障害ではないため
  # 送信しない。予期しないOOM等のSIGTERMも見えなくなるトレードオフは許容する
  config.excluded_exceptions += %w[SystemExit SignalException]

  # send_default_piiは有効にしない: sentry-rubyのNet::HTTPパッチが外部APIリクエストの
  # クエリ文字列（EDINETのSubscription-Key）とボディまでSentryへ送出してしまうため
  config.send_default_pii = false
  # 本番は間引く: /graphqlは未認証で誰でも叩けるため、全リクエストをトレースすると
  # 大量リクエストでSentryのクォータを消費する。エラー通知はこの値に影響されない
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0

  # 保険: http系breadcrumbにクエリ文字列が載る経路を将来の設定変更からも遮断する
  config.before_breadcrumb = lambda do |breadcrumb, _hint|
    breadcrumb.data.delete(:query) if breadcrumb.category == "net.http" && breadcrumb.data.is_a?(Hash)
    breadcrumb
  end
end
