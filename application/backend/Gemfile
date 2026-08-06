source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.0.8", ">= 7.0.8.7"

# rackはRailsの間接依存だが、未認証リクエストが必ず通る層のため
# 既知脆弱性（パラメータ数/メモリ量無制限のDoS群）修正版を明示する
gem "rack", "~> 2.2.23"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 5.6", ">= 5.6.9"

# sidekiq-cronがsidekiqに依存しており、sidekiqのバージョンを明示しないと7.0以上が使用されるが、エラーとなってしまうため
gem "sidekiq", "~> 6.5", ">= 6.5.10"
gem "sidekiq-cron", "~> 1.8"

gem "graphql", "~> 2.1.15"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem 'rubyzip', require: 'zip'
gem "figaro"

# XBRLパース用。REXMLは有報の巨大TextBlock（HTML断片）でentity expansionエラーになるためNokogiriを使う
gem "nokogiri", "~> 1.18.9"

gem 'lograge'
gem "sentry-ruby"
gem "sentry-rails"


# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "webmock", "~> 3.19"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  gem 'graphiql-rails'
  gem 'sass-rails'
end

