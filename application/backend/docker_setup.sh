#!/bin/bash

PROJECT_ROOT_DIR=/home/app/financialStatement

bundle install --path vendor/bundle

if [ -f $PROJECT_ROOT_DIR/tmp/pids/server.pid ]; then
  rm $PROJECT_ROOT_DIR/tmp/pids/server.pid
fi

bundle exec sidekiq -e development -C config/sidekiq.yml &
bundle exec rake db:migrate
bundle exec ./bin/rails s -b '0.0.0.0'
