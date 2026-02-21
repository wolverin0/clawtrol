# frozen_string_literal: true

namespace :agent_activity do
  desc "Prune agent activity events older than N days (default: keep forever, set DAYS=30/60/90 etc.)"
  task prune: :environment do
    days = ENV["DAYS"].to_i
    if days <= 0
      puts "No pruning executed. Set DAYS (e.g. DAYS=30) to delete old records."
      next
    end

    cutoff = days.days.ago
    deleted = AgentActivityEvent.where("created_at < ?", cutoff).delete_all
    puts "Deleted #{deleted} agent activity events older than #{days} days (before #{cutoff.iso8601})"
  end
end
