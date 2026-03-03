# frozen_string_literal: true

namespace :zeroclaw do
  desc "Generate ZeroClaw auditor report for recent tasks (default 7 days)"
  task :auditor_report, [:days] => :environment do |_task, args|
    days = args[:days].to_i
    days = 7 if days <= 0

    from = days.days.ago
    to = Time.current

    scoped = Task.where("updated_at >= ?", from).where.not(review_result: [nil, {}])
    with_auditor = scoped.select { |task| task.review_result.is_a?(Hash) && task.review_result["auditor"].is_a?(Hash) }

    verdicts = Hash.new(0)
    task_types = Hash.new(0)
    scores = []

    with_auditor.each do |task|
      data = task.review_result["auditor"] || {}
      verdict = data["verdict"].to_s.presence || "unknown"
      task_type = data["task_type"].to_s.presence || "unknown"

      verdicts[verdict] += 1
      task_types[task_type] += 1

      score = data["score"]
      scores << score.to_i if score.present?
    end

    avg_score = scores.any? ? (scores.sum.to_f / scores.size).round(1) : 0.0

    puts "ZeroClaw Auditor Report"
    puts "Window: #{from.iso8601} .. #{to.iso8601} (#{days} days)"
    puts "Total audited tasks: #{with_auditor.size}"
    puts "Average score: #{avg_score}"
    puts "Verdicts: #{verdicts.sort.to_h}"
    puts "Task types: #{task_types.sort.to_h}"
  end

  desc "Enqueue ZeroClaw auditor sweep for tasks currently in_review"
  task :auditor_sweep, [:limit, :force, :min_interval_seconds, :lookback_hours] => :environment do |_task, args|
    limit = args[:limit].to_i
    limit = Zeroclaw::AuditorConfig.sweep_limit if limit <= 0

    force = ActiveModel::Type::Boolean.new.cast(args[:force])

    min_interval_seconds = args[:min_interval_seconds].to_i
    min_interval_seconds = Zeroclaw::AuditorConfig.min_interval_seconds if min_interval_seconds <= 0

    lookback_hours = args[:lookback_hours].to_i
    lookback_hours = Zeroclaw::AuditorConfig.sweep_lookback_hours if lookback_hours <= 0

    result = Zeroclaw::AuditorSweepService.new(
      trigger: "cron_sweep",
      limit: limit,
      force: force,
      min_interval_seconds: min_interval_seconds,
      lookback_hours: lookback_hours
    ).call

    puts "Auditor sweep result: #{result}"
  end
end
