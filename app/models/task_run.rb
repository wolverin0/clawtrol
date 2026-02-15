# frozen_string_literal: true

class TaskRun < ApplicationRecord
  belongs_to :task

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
