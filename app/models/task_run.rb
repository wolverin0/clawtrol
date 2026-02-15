# frozen_string_literal: true

class TaskRun < ApplicationRecord
  # Enforce eager loading to prevent N+1 queries in views
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :task, inverse_of: :task

  RECOMMENDED_ACTIONS = %w[
    in_review
    requeue_same_task
    split_into_subtasks
    prompt_user
  ].freeze

  validates :run_id, presence: true, uniqueness: true
  validates :run_number, presence: true, uniqueness: { scope: :task_id, message: "must be unique per task" }
  validates :recommended_action, presence: true, inclusion: { in: RECOMMENDED_ACTIONS }
end
