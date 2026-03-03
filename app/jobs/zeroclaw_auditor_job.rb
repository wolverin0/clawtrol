# frozen_string_literal: true

class ZeroclawAuditorJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(task_id, trigger: "auto", force: false)
    return unless Zeroclaw::AuditorConfig.enabled?

    task = Task.find(task_id)

    unless task.status == "in_review" && task.assigned_to_agent?
      Rails.logger.info("[ZeroclawAuditorJob] task=#{task.id} skipped status=#{task.status} assigned=#{task.assigned_to_agent?}")
      return
    end

    unless Zeroclaw::AuditableTask.auditable?(task)
      Rails.logger.info("[ZeroclawAuditorJob] task=#{task.id} skipped not auditable")
      return
    end

    if should_skip_recent?(trigger, force) && Zeroclaw::AuditableTask.recently_audited?(task)
      Rails.logger.info("[ZeroclawAuditorJob] task=#{task.id} skipped recently audited trigger=#{trigger}")
      return
    end

    result = Zeroclaw::AuditorService.new(task, trigger: trigger).call
    Rails.logger.info("[ZeroclawAuditorJob] task=#{task.id} verdict=#{result[:verdict]} score=#{result[:score]}")
    result
  rescue StandardError => e
    Rails.logger.error("[ZeroclawAuditorJob] task=#{task_id} failed: #{e.class}: #{e.message}")
    raise
  end

  private

  def should_skip_recent?(trigger, force)
    return false if force

    %w[cron_sweep webhook].include?(trigger.to_s)
  end
end
