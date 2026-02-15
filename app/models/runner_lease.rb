# frozen_string_literal: true

class RunnerLease < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :task

  LEASE_DURATION = 15.minutes

  scope :active, -> { where(released_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where(released_at: nil).where("expires_at <= ?", Time.current) }

  validates :lease_token, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :started_at, :last_heartbeat_at, :expires_at, presence: true
  validates :agent_name, length: { maximum: 100 }, allow_nil: true
  validates :source, length: { maximum: 50 }, allow_nil: true
  validates :released_at, presence: true, if: -> { persisted? && released_at.present? }

  validate :expires_after_started
  validate :last_heartbeat_after_started

  private

  def expires_after_started
    return unless started_at.present? && expires_at.present?
    if expires_at <= started_at
      errors.add(:expires_at, "must be after started_at")
    end
  end

  def last_heartbeat_after_started
    return unless started_at.present? && last_heartbeat_at.present?
    if last_heartbeat_at < started_at
      errors.add(:last_heartbeat_at, "must be after started_at")
    end
  end

  # Factory: create a new lease for a task with consistent defaults.
  # @param task [Task] the task to lease
  # @param agent_name [String] name of the agent claiming the lease
  # @param source [String] where the lease originated (e.g. "api_claim", "spawn_ready")
  # @return [RunnerLease]
  def self.create_for_task!(task:, agent_name:, source:)
    now = Time.current
    create!(
      task: task,
      agent_name: agent_name,
      lease_token: SecureRandom.hex(24),
      source: source,
      started_at: now,
      last_heartbeat_at: now,
      expires_at: now + LEASE_DURATION
    )
  end

  def active?
    released_at.nil? && expires_at.present? && expires_at > Time.current
  end

  def heartbeat!
    now = Time.current
    update!(last_heartbeat_at: now, expires_at: now + LEASE_DURATION)
  end

  def release!
    update!(released_at: Time.current)
  end
end
