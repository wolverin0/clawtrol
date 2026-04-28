# frozen_string_literal: true

# DB safety guards
#
# These hooks prevent destructive db: tasks from running against a database
# whose name doesn't match the conventional test/development suffixes. They
# specifically defend against the failure mode where DATABASE_URL (loaded from
# /etc/clawtrol/clawtrol.env) silently shadows RAILS_ENV=test on the VM, so
# `RAILS_ENV=test bundle exec rails db:schema:load` ends up running against
# clawdeck_development. That happened 2026-04-27 and wiped prod.
#
# Bypass with FORCE_DESTRUCTIVE_DB=1 if you really mean it.

DESTRUCTIVE_DB_TASKS = %w[
  db:drop
  db:drop:_unsafe
  db:drop:all
  db:reset
  db:schema:load
  db:schema:load:primary
  db:setup
  db:purge
  db:purge:all
].freeze

PROTECTED_DB_NAME_PATTERN = /(_test\b|_test_\d+\b|_development\b|playground)/

DESTRUCTIVE_DB_TASKS.each do |task_name|
  next unless Rake::Task.task_defined?(task_name)

  Rake::Task[task_name].enhance(["db:safety:guard"])
end

namespace :db do
  namespace :safety do
    desc "Abort if the current DB looks like production"
    task guard: :environment do
      next if ENV["FORCE_DESTRUCTIVE_DB"] == "1"

      configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)
      configs.each do |config|
        db_name = config.database.to_s
        next if db_name.empty?

        unless db_name.match?(PROTECTED_DB_NAME_PATTERN) && !db_name.start_with?("clawdeck_development")
          warn <<~MSG

            ❌ DB SAFETY GUARD blocked a destructive task on:
                database: #{db_name}
                env:      #{Rails.env}
                source:   #{config.configuration_hash[:url] ? 'DATABASE_URL' : 'database.yml'}

            This database name doesn't look like a safe test/dev target.
            Common cause: DATABASE_URL set in your shell/env file overrides
            RAILS_ENV. Run `unset DATABASE_URL DATABASE_ADMIN_URL` first, or
            re-run with FORCE_DESTRUCTIVE_DB=1 if you really mean it.

          MSG
          abort "blocked by db:safety:guard"
        end
      end
    end
  end
end
