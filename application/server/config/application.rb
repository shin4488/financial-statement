require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"

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

    config.middleware.use ActionDispatch::Session::CookieStore
    config.paths.add 'lib', eager_load: true
    # https://weseek.co.jp/tech/680/
    # DNSリバインディング攻撃制御に対応するため、nginxで定義されているサーバ名からのリクエストは受け付ける
    config.hosts << ENV["SERVER_HOST_NAME"] if ENV["SERVER_HOST_NAME"].present?

    config.lograge.enabled = true
    config.logger = Logger.new("log/#{Rails.env}.log", 'weekly')
    config.logger.formatter = proc do |severity, datetime, progname, message|
      severity_with_bracket = "[#{severity}]"
      "#{severity_with_bracket.rjust(7)}[#{datetime.in_time_zone.to_s}]: #{progname} : #{message}\n"
    end
    ActiveRecord::Base.logger = Logger.new("log/sql_#{Rails.env}.log", 'weekly')
  end
end
