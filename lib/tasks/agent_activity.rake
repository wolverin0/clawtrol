# frozen_string_literal: true

namespace :agent_activity do
  desc "Backfill agent activity sidecar events from transcript files (TASK_ID=123 optional, LIMIT=1000 default)"
  task backfill: :environment do
    limit = ENV.fetch("LIMIT", "1000").to_i
    relation = Task.where.not(agent_session_id: [nil, ""]).order(:id)
    relation = relation.where(id: ENV["TASK_ID"].to_i) if ENV["TASK_ID"].present?
    relation = relation.limit(limit) if limit.positive?

    processed = 0
    created_total = 0
    duplicates_total = 0

    relation.find_each do |task|
      session_id = task.agent_session_id.to_s
      path = TranscriptParser.transcript_path(session_id)
      next unless path

      parsed = TranscriptParser.parse_messages(path, since: 0)
      run_id = task.last_run_id.presence || session_id.presence || "task-#{task.id}"

      events = parsed[:messages].filter_map do |msg|
        seq = msg[:line].to_i
        next if seq <= 0

        {
          run_id: run_id,
          source: "backfill",
          level: "info",
          event_type: (msg[:role].to_s == "toolResult" ? "tool_result" : "message"),
          message: Array(msg[:content]).filter_map { |c| c[:text].presence }.join("\n").slice(0, 5000),
          seq: seq,
          created_at: msg[:timestamp],
          payload: { role: msg[:role], raw: msg }
        }
      end

      result = AgentActivityIngestionService.call(task: task, events: events)
      processed += 1
      created_total += result.created
      duplicates_total += result.duplicates

      puts "task=#{task.id} session=#{session_id} lines=#{parsed[:total_lines]} created=#{result.created} dup=#{result.duplicates}"
    rescue StandardError => e
      puts "task=#{task.id} ERROR #{e.class}: #{e.message}"
    end

    puts "Backfill complete: processed=#{processed} created=#{created_total} duplicates=#{duplicates_total}"
  end

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
