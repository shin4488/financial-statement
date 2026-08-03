require_relative "boot"

require "rails"
# Pick the frameworks you want:
# ActiveStorage・ActionMailer/Mailbox/Text・ActionCableは未使用のため読み込まない
# （未認証で到達可能な /rails/active_storage/* 等のエンドポイントが本番に生えるのを防ぐ）
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "net/http"
require "open-uri"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FinancialStatement
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # ActiveRecordやTime.zoneで扱うタイムゾーン
    config.time_zone = 'Tokyo'
    # DBに書かれている時刻をどのタイムゾーンとして解釈するか、時刻をDBに書き込むときどのタイムゾーンで書き込むか（DBのタイムゾーン）
    config.active_record.default_timezone = :utc

    config.paths.add 'lib', eager_load: true
    # https://weseek.co.jp/tech/680/
    # DNSリバインディング攻撃制御に対応するため、nginxで定義されているサーバ名からのリクエストは受け付ける
    config.hosts << ENV["SERVER_HOST_NAME"] if ENV["SERVER_HOST_NAME"].present?

    config.lograge.enabled = true
    # ローテーションは世代数*サイズ上限つき: 'weekly'指定は古い世代を無限に残すため、
    # ディスク枯渇（可用性）対策として上限を明示する
    config.logger = Logger.new("log/#{Rails.env}.log", 10, 100 * 1024 * 1024)
    config.logger.formatter = proc do |severity, datetime, progname, message|
      severity_with_bracket = "[#{severity}]"
      "#{severity_with_bracket.rjust(7)}[#{datetime.in_time_zone.to_s}]: #{progname} : #{message}\n"
    end
    sql_logger = Logger.new("log/sql_#{Rails.env}.log", 5, 100 * 1024 * 1024)
    # SQLログ（DEBUGレベル）は開発時のみ。config.log_levelはこの直接代入loggerには
    # 効かないため、本番で全SQLが書かれ続けないようレベルをここで明示する
    sql_logger.level = Rails.env.production? ? Logger::WARN : Logger::DEBUG
    ActiveRecord::Base.logger = sql_logger
  end
end
