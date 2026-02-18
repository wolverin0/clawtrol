# frozen_string_literal: true

require "open3"
require "timeout"

class NightshiftSyncService
  # Sync OpenClaw crons into nightshift_missions and create tonight's selections
  def sync_crons
    crons = fetch_nightshift_crons
    synced = 0
    selections_created = 0

    crons.each do |cron|
      raw_name = cron["name"].to_s
      mission_name = raw_name.sub(/^🌙\s*NS:\s*/, "").strip
      next if mission_name.blank?

      mission = NightshiftMission.find_or_initialize_by(name: mission_name)
      if mission.new_record?
        mission.assign_attributes(
          enabled: cron["enabled"] != false,
          frequency: "always",
          category: "general",
          icon: "🌙",
          description: "Auto-synced from OpenClaw cron: #{raw_name}",
          estimated_minutes: ((cron.dig("payload", "timeoutSeconds") || 300) / 60.0).ceil
        )
        mission.save!
      end
      synced += 1

      next unless mission.enabled? && mission.due_tonight?
      # If mission has a scheduled_hour, only create selection once we're within 1h of that hour
      if mission.scheduled_hour.present?
        current_hour = Time.current.in_time_zone("America/Argentina/Buenos_Aires").hour
        next unless current_hour == mission.scheduled_hour
      end
      next if NightshiftSelection.for_tonight.exists?(nightshift_mission_id: mission.id)

      NightshiftSelection.create!(
        nightshift_mission_id: mission.id,
        title: mission.name,
        scheduled_date: Date.current,
        enabled: true,
        status: "pending"
      )
      selections_created += 1
    end

    { synced: synced, selections_created: selections_created }
  end

  # Create selections for all due missions tonight
  def sync_tonight_selections
    created = 0
    NightshiftMission.enabled.select(&:due_tonight?).each do |mission|
      sel = NightshiftSelection.find_or_initialize_by(
        nightshift_mission_id: mission.id,
        scheduled_date: Date.current
      )
      if sel.new_record?
        sel.title = mission.name
        sel.enabled = true
        sel.status = "pending"
        sel.save!
        created += 1
      end
    end
    created
  end

  private

  def fetch_nightshift_crons
    stdout, _stderr, status = Timeout.timeout(20) do
      Open3.capture3("openclaw", "cron", "list", "--json")
    end
    return [] unless status&.exitstatus == 0

    raw = JSON.parse(stdout)
    Array(raw["jobs"]).select { |j| j["name"].to_s.include?("🌙 NS:") }
  rescue StandardError => e
    Rails.logger.warn("[NightshiftSyncService] Failed to fetch crons: #{e.message}")
    []
  end
end
