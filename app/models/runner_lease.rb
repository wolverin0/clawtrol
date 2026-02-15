# frozen_string_literal: true

class RunnerLease < ApplicationRecord
  belongs_to :task

  LEASE_DURATION = 15.minutes

  scope :active, -> { where(released_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where(released_at: nil).where("expires_at <= ?", Time.current) }

  validates :lease_token, presence: true, uniqueness: true
  validates :started_at, :last_heartbeat_at, :expires_at, presence: true

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
