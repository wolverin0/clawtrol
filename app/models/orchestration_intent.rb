# frozen_string_literal: true

class OrchestrationIntent < ApplicationRecord
  KINDS = %w[create_task message approve retry cancel].freeze
  STATUSES = %w[pending applied rejected].freeze

  belongs_to :user, inverse_of: :orchestration_intents
  belongs_to :orchestration_source, inverse_of: :orchestration_intents
  belongs_to :task, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :source_belongs_to_user
  validate :task_belongs_to_user

  scope :pending, -> { where(status: "pending").order(:id) }
  scope :recent, -> { order(created_at: :desc) }

  def as_bridge_json
    {
      id:,
      kind:,
      task_origin_key: task&.origin_session_key,
      payload:,
      created_at: created_at.iso8601
    }
  end

  private

  def source_belongs_to_user
    return if orchestration_source.blank? || user_id == orchestration_source.user_id

    errors.add(:orchestration_source, "must belong to the same user")
  end

  def task_belongs_to_user
    return if task.blank? || user_id == task.user_id

    errors.add(:task, "must belong to the same user")
  end
end
