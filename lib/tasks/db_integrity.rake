# frozen_string_literal: true

# Schema integrity drift detector
#
# Catches the failure mode where schema_migrations marks a migration as
# applied but the columns / indexes the migration was supposed to create
# are missing in the live DB. That happened to the pipeline_* columns on
# tasks (PR #33) and went undetected for weeks.
#
# Two sub-tasks:
#   db:integrity:migrations  — every migration file has a row in schema_migrations
#   db:integrity:expected    — a curated list of (table, column) pairs we know must exist

EXPECTED_COLUMNS = {
  "tasks" => %w[
    pipeline_stage pipeline_type pipeline_enabled pipeline_log
    status priority assigned_to_agent agent_session_id
  ],
  "users" => %w[email_address password_digest agent_auto_mode],
  "boards" => %w[name user_id],
  "api_tokens" => %w[token_digest token_prefix user_id],
  "agent_activity_events" => %w[task_id run_id event_type seq],
  "task_runs" => %w[task_id run_id run_number]
}.freeze

namespace :db do
  namespace :integrity do
    desc "Verify every migration file has a row in schema_migrations"
    task migrations: :environment do
      file_versions = Dir.glob(Rails.root.join("db/migrate/*.rb"))
        .map { |p| File.basename(p).split("_").first }
        .sort

      db_versions = ActiveRecord::Base.connection
        .execute("SELECT version FROM schema_migrations ORDER BY version")
        .map { |r| r["version"] }

      missing_in_db = file_versions - db_versions
      missing_in_files = db_versions - file_versions

      # Orphan rows in schema_migrations (no matching file) are usually the
      # result of squashed/deleted migrations and aren't a runtime risk —
      # warn but don't abort. The dangerous case is a file that should have
      # run but didn't, so we abort only when missing_in_db is non-empty.
      if missing_in_files.any?
        puts "⚠️  schema_migrations has #{missing_in_files.size} orphan rows (no matching file): #{missing_in_files.first(5).inspect}#{missing_in_files.size > 5 ? '…' : ''}"
        puts "    Likely from squashed/removed migrations. Not blocking."
      end

      if missing_in_db.any?
        puts "❌ Migration files not applied:"
        missing_in_db.each { |v| puts "  - #{v}" }
        abort
      end

      puts "✅ #{file_versions.size} migration files all applied"
    end

    desc "Verify expected (table, column) pairs exist in the DB"
    task expected: :environment do
      missing = []

      EXPECTED_COLUMNS.each do |table, cols|
        unless ActiveRecord::Base.connection.table_exists?(table)
          missing << "#{table} (table)"
          next
        end

        actual = ActiveRecord::Base.connection.columns(table).map(&:name)
        cols.each do |col|
          missing << "#{table}.#{col}" unless actual.include?(col)
        end
      end

      if missing.any?
        puts "❌ Schema integrity drift — expected columns missing:"
        missing.each { |m| puts "  - #{m}" }
        abort
      end

      total = EXPECTED_COLUMNS.values.flatten.size
      puts "✅ #{total} expected columns across #{EXPECTED_COLUMNS.size} tables all present"
    end

    desc "Run all DB integrity checks"
    task check: ["db:integrity:migrations", "db:integrity:expected"]
  end
end
