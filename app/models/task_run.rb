# frozen_string_literal: true

class TaskRun < ApplicationRecord
  # Enforce eager loading to prevent N+1 queries in views
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

belongs_to :task, inverse_of: :task_runs

# Broadcast panel update when a TaskRun is created or updated
after_create_commit :broadcast_task_panel_update
after_update_commit :broadcast_task_panel_update


  RECOMMENDED_ACTIONS = %w[
    in_review
    requeue_same_task
    split_into_subtasks
    prompt_user
  ].freeze

  validates :run_id, presence: true, uniqueness: true
  validates :run_number, presence: true, uniqueness: { scope: :task_id, message: "must be unique per task" }
  validates :recommended_action, presence: true, inclusion: { in: RECOMMENDED_ACTIONS }

  # --- Scopes ---
  scope :recent, -> { order(created_at: :desc) }
  scope :for_task, ->(task_id) { where(task_id: task_id) }
  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }
  scope :by_model, ->(model) { where(model_used: model) }
  scope :needs_follow_up, -> { where(needs_follow_up: true) }

  # --- Output contract helpers ---

  def changes
    normalize_list(raw_payload["changes"] || raw_payload[:changes])
  end

  def validation
    raw_payload["validation"] || raw_payload[:validation]
  end

  def follow_up
    normalize_list(raw_payload["follow_up"] || raw_payload[:follow_up])
  end

# Broadcast a Turbo Stream update to refresh the task panel when run data changes
def broadcast_task_panel_update
  return unless task_id.present?
  KanbanChannel.broadcast_refresh(
    task.board_id,
    task_id: task_id,
    action: "update",
    old_status: task.status,
    new_status: task.status
  )
rescue StandardError => e
  Rails.logger.warn("[TaskRun##{id}] broadcast_task_panel_update failed: #{e.message}")
end

private


  def normalize_list(value)
    case value
    when Array
      value.map(&:to_s).map(&:strip).reject(&:blank?)
    when String
      value.lines.map(&:strip).reject(&:blank?)
    else
      []
    end
  end
end
