# frozen_string_literal: true

class FactoryCycleLog < ApplicationRecord
  # The 'errors' column conflicts with ActiveRecord::Base#errors in Rails 8.1+
  self.ignored_columns += ["errors"]

  belongs_to :factory_loop, inverse_of: :factory_cycle_logs
  belongs_to :user, optional: true, inverse_of: :factory_cycle_logs

  STATUSES = %w[pending running completed failed skipped timed_out].freeze

  validates :cycle_number, :started_at, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :cycle_number, uniqueness: { scope: :factory_loop_id }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_loop, ->(loop_id) { where(factory_loop_id: loop_id) }

  # Delegate user to factory_loop for convenience
  delegate :user, to: :factory_loop, allow_nil: true
end
