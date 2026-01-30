#!/usr/bin/env bash
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails db:migrate
bundle exec rails db:migrate:cable
bundle exec rails db:migrate:cache
bundle exec rails db:migrate:queue
