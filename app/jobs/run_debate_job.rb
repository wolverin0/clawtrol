# frozen_string_literal: true

require "open3"
require "shellwords"
require "fileutils"

# RunDebateJob - Multi-Model Debate Review System
#
# CURRENT STATE (2026-02-15): MOCK IMPLEMENTATION
# ================================================
# This job currently generates a placeholder synthesis instead of
# actually calling multiple LLM models for debate.
#
# Status: NOT YET IMPLEMENTED - Returns "not yet implemented" result
#
# TODO: When implementing real debate:
# - Use debate skill: /debate [-r N] [-d STYLE] <question>
# - Spawn multiple AI agents (gemini, claude, glm) in parallel  
# - Have them debate the task's implementation quality
# - Generate a real synthesis from their perspectives
#
class RunDebateJob < ApplicationJob
  include TaskBroadcastable

  queue_as :default

  # This job is a placeholder for the future multi-model debate feature.
  # When triggered, it immediately marks the review as failed with a
  # "not yet implemented" message.

  discard_on ActiveRecord::RecordNotFound

  def perform(task_id)
    task = Task.find(task_id)
    return unless task.review_status == "pending" && task.debate_review?

    task.update!(review_status: "running")
    broadcast_task_update(task)

    task.complete_review!(
      status: "failed",
      result: {
        error_summary: "Debate review is not yet implemented. Coming soon.",
        not_implemented: true
      }
    )

    broadcast_task_update(task)
  rescue StandardError => e
    task&.complete_review!(
      status: "failed",
      result: { error_summary: "Debate job crashed: #{e.message}" }
    )
    broadcast_task_update(task) if task
    raise
  end

end
