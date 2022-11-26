#!/bin/bash

bundle install --path vendor/bundle

if [ -f /home/app/financialStatement/tmp/pids/server.pid ]; then
  rm /home/app/financialStatement/tmp/pids/server.pid
fi

bundle exec sidekiq -e development -C config/sidekiq.yml &
bundle exec ./bin/rails s -b '0.0.0.0'
