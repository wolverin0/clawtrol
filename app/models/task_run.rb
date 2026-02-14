class TaskRun < ApplicationRecord
  belongs_to :task
  has_one :agent_transcript, dependent: :nullify

  RECOMMENDED_ACTIONS = %w[
    in_review
    requeue_same_task
    split_into_subtasks
    prompt_user
  ].freeze

  validates :run_id, presence: true, uniqueness: true
  validates :run_number, presence: true
  validates :recommended_action, presence: true, inclusion: { in: RECOMMENDED_ACTIONS }
end
