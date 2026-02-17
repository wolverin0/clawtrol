# frozen_string_literal: true

class FactoryAgent < ApplicationRecord
  strict_loading :n_plus_one

  has_many :factory_loop_agents, dependent: :destroy, inverse_of: :factory_agent
  has_many :factory_loops, through: :factory_loop_agents
  has_many :factory_agent_runs, dependent: :destroy, inverse_of: :factory_agent

  RUN_CONDITIONS = %w[new_commits daily weekly always].freeze
  CATEGORIES = %w[quality-security code-quality performance testing docs architecture bug-fix].freeze

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :system_prompt, presence: true
  validates :run_condition, inclusion: { in: RUN_CONDITIONS }
  validates :cooldown_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :default_confidence_threshold, numericality: { only_integer: true, in: 0..100 }
  validates :priority, numericality: { only_integer: true, in: 1..10 }

  scope :enabled, -> { joins(:factory_loop_agents).merge(FactoryLoopAgent.enabled).distinct }
  scope :builtin, -> { where(builtin: true) }
  scope :custom, -> { where(builtin: false) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :by_priority, -> { order(priority: :asc) }
  scope :ordered, -> { order(:name) }

  before_validation :normalize_slug

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end
end
