# frozen_string_literal: true

class PipelineProcessorJob < ApplicationJob
  queue_as :default

  MAX_ITERATIONS = 5

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task
    return unless task.pipeline_enabled?
    return if task.pipeline_stage.in?(%w[routed executing completed failed])

    orchestrator = Pipeline::Orchestrator.new(task, user: task.user)
    final_stage = orchestrator.process_to_completion!

    Rails.logger.info("[PipelineProcessorJob] task_id=#{task_id} final_stage=#{final_stage}")
  rescue StandardError => e
    Rails.logger.error("[PipelineProcessorJob] task_id=#{task_id} error=#{e.class}: #{e.message}")

    task = Task.find_by(id: task_id)
    if task
      log_entry = { stage: "error", error: "#{e.class}: #{e.message}", at: Time.current.iso8601 }
      current_log = Array(task.pipeline_log)
      task.update_columns(
        pipeline_stage: "failed",
        pipeline_log: current_log.push(log_entry)
      )
    end
  end
end
