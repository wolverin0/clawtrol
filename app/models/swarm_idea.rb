class SwarmIdea < ApplicationRecord
  belongs_to :user

  CATEGORIES = %w[code research marketing infra fitness finance personal].freeze
  MODELS = %w[opus codex gemini glm groq cerebras minimax flash].freeze
  SOURCES = %w[manual otacon reddit x perplexity backlog].freeze
  DIFFICULTIES = %w[trivial standard complex].freeze
  PIPELINE_TYPES = %w[quick-fix bug-fix feature research architecture].freeze

  validates :title, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :suggested_model, inclusion: { in: MODELS }, allow_blank: true
  validates :difficulty, inclusion: { in: DIFFICULTIES }, allow_blank: true
  validates :pipeline_type, inclusion: { in: PIPELINE_TYPES }, allow_blank: true

  scope :enabled, -> { where(enabled: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_source, ->(src) { where(source: src) }
  scope :popular, -> { order(times_launched: :desc) }
end
