# frozen_string_literal: true

class FactoryAgentRun < ApplicationRecord
  strict_loading :n_plus_one

  belongs_to :factory_loop, inverse_of: :factory_agent_runs
  belongs_to :factory_agent, inverse_of: :factory_agent_runs
  belongs_to :factory_cycle_log, optional: true, inverse_of: :factory_agent_runs

  STATUSES = %w[clean findings error].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :findings_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :items_generated, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_agent, ->(agent_id) { where(factory_agent_id: agent_id) }
  scope :for_loop, ->(loop_id) { where(factory_loop_id: loop_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_findings, -> { where(status: "findings") }
  scope :clean, -> { where(status: "clean") }
  scope :errored, -> { where(status: "error") }

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).to_i
  end

  def eligible?(loop: nil)
    agent = factory_agent
    target_loop = loop || factory_loop

    # Check cooldown
    override = target_loop.factory_loop_agents.find_by(factory_agent_id: agent.id)
    cooldown = override&.cooldown_hours_override || agent.cooldown_hours
    last_run = self.class.where(factory_loop_id: target_loop.id, factory_agent_id: agent.id)
                         .order(created_at: :desc).first
    return false if last_run&.created_at && last_run.created_at > cooldown.hours.ago

    true
  end
end
