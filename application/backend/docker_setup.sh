#!/bin/bash

PROJECT_ROOT_DIR=/home/app/financialStatement

# Bundlerの設定はコンテナの中（BUNDLE_APP_CONFIG）にだけ保存され、作り直したコンテナには残らないため、起動のたびに設定する
bundle config set --local path vendor/bundle
bundle install

if [ -f $PROJECT_ROOT_DIR/tmp/pids/server.pid ]; then
  rm $PROJECT_ROOT_DIR/tmp/pids/server.pid
fi

bundle exec sidekiq -e development -C config/sidekiq.yml &
bundle exec rake db:migrate
bundle exec ./bin/rails s -b '0.0.0.0'
