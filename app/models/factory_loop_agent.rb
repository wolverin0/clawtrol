# frozen_string_literal: true

class FactoryLoopAgent < ApplicationRecord
  strict_loading :n_plus_one

  belongs_to :factory_loop, inverse_of: :factory_loop_agents
  belongs_to :factory_agent, inverse_of: :factory_loop_agents

  validates :factory_agent_id, uniqueness: { scope: :factory_loop_id, message: "is already assigned to this loop" }
  validates :cooldown_hours_override, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :confidence_threshold_override, numericality: { only_integer: true, in: 0..100 }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }

  def effective_cooldown_hours
    cooldown_hours_override || factory_agent.cooldown_hours
  end

  def effective_confidence_threshold
    confidence_threshold_override || factory_loop.confidence_threshold || factory_agent.default_confidence_threshold
  end
end
