# frozen_string_literal: true

# Default cron jobs that ship with ClawTrol.
# Idempotent: skips if already provisioned.
# Run manually: rails skill_store:provision_cron

puts "== Provisioning default crons =="

# Skill Store Auto-Update (daily at 05:00 ART)
Rake::Task["skill_store:provision_cron"].invoke rescue nil
