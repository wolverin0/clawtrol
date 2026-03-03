# frozen_string_literal: true

require "time"

class LearningEffectivenessService
  ADVISORY_LOG_PATH = File.expand_path("~/.openclaw/workspace/memory/advisory_log.jsonl")

  # Called after TaskOutcomeService processes a task outcome.
  # Links surfaced learnings to the task result for effectiveness tracking.
  #
  # @param task [Task] the completed task
  # @param task_run [TaskRun] the task run record
  def self.call(task, task_run)
    new(task, task_run).record
  end

  def initialize(task, task_run)
    @task = task
    @task_run = task_run
  end

  def record
    advisories = find_advisories_for_task
    return if advisories.empty?

    task_succeeded = determine_success

    advisories.each do |advisory|
      surfaced_at = begin
        Time.parse(advisory["surfaced_at"])
      rescue ArgumentError
        Time.current
      end

      LearningEffectiveness.create!(
        task: @task,
        task_run: @task_run,
        learning_entry_id: advisory["entry_id"],
        learning_title: advisory["title"],
        task_succeeded: task_succeeded,
        needs_follow_up: @task_run&.needs_follow_up || false,
        recommended_action: @task_run&.recommended_action,
        surfaced_at: surfaced_at
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[LearningEffectivenessService] Failed to record: #{e.message}")
  end

  private

  def find_advisories_for_task
    return [] unless File.exist?(ADVISORY_LOG_PATH)

    task_id = @task.id
    advisories = []

    File.foreach(ADVISORY_LOG_PATH, encoding: "UTF-8").with_index do |line, idx|
      begin
        entry = JSON.parse(line.strip)
      rescue JSON::ParserError => e
        Rails.logger.debug("[LearningEffectivenessService] Skipping malformed line #{idx}: #{e.message}")
        next
      end
      next unless entry["task_id"] == task_id

      (entry["advisories"] || []).each do |a|
        advisories << a.merge("surfaced_at" => entry["timestamp"])
      end
    end

    advisories
  end

  def determine_success
    return false if @task_run.nil?

    !@task_run.needs_follow_up &&
      %w[in_review complete archive].include?(@task_run.recommended_action.to_s)
  end
end
