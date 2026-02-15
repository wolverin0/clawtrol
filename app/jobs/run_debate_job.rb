# frozen_string_literal: true

require "open3"
require "shellwords"
require "fileutils"

# RunDebateJob - Multi-Model Debate Review System
#
# CURRENT STATE (2026-02-05): MOCK IMPLEMENTATION
# ================================================
# This job currently generates a FAKE synthesis file instead of
# actually calling multiple LLM models for debate.
#
# What it SHOULD do:
# - Spawn multiple AI agents (gemini, claude, glm) in parallel
# - Have them debate the task's implementation quality
# - Generate a real synthesis from their perspectives
# - Use the debate skill: /debate [-r N] [-d STYLE] <question>
#
# What it CURRENTLY does:
# - Creates a placeholder synthesis.md with pre-written content
# - Always returns "PASS" unless hardcoded keywords are present
# - Does NOT call any external LLM APIs
#
# TODO: Implement real multi-model debate (see issue #XXX)
# - Requires: OpenClaw multi-agent spawning
# - Requires: debate skill integration
# - Requires: synthesis merging logic
#
class RunDebateJob < ApplicationJob
  include TaskBroadcastable

  queue_as :default

  # STATUS: NOT YET IMPLEMENTED — Coming Soon
  #
  # This job is a placeholder for the future multi-model debate feature.
  # When triggered, it immediately marks the review as failed with a
  # "not yet implemented" message. The class structure is kept intact
  # so it's easy to implement later.
  #
  # TODO: Implement real multi-model debate
  # - Spawn multiple AI agents (gemini, claude, glm) in parallel
  # - Have them debate the task's implementation quality
  # - Generate a real synthesis from their perspectives
  # - Use the debate skill: /debate [-r N] [-d STYLE] <question>

  # Don't retry — debate is not yet implemented anyway
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
    # Mark review as failed so UI doesn't show perpetual "running"
    task&.complete_review!(
      status: "failed",
      result: { error_summary: "Debate job crashed: #{e.message}" }
    )
    broadcast_task_update(task) if task
    raise
  end

end
