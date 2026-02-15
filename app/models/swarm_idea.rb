# frozen_string_literal: true

# == Schema Information
#
# Table name: swarm_ideas
#
#  id                :bigint           not null, primary key
#  user_id           :bigint           not null
#  title             :string           not null
#  description       :text
#  category          :string
#  suggested_model   :string
#  source            :string
#  project           :string
#  estimated_minutes :integer
#  icon              :string
#  difficulty        :string
#  pipeline_type     :string
#  enabled           :boolean          default(TRUE)
#  times_launched    :integer          default(0)
#  last_launched_at  :datetime
#  favorite          :boolean          default(FALSE)
#  board_id          :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class SwarmIdea < ApplicationRecord
  MODELS = %w[opus codex gemini glm groq cerebras minimax flash].freeze
  CATEGORIES = %w[code research marketing infra fitness finance personal].freeze
  belongs_to :user
  belongs_to :board, optional: true

  # --- Scopes ---
  scope :favorites, -> { where(favorite: true) }
  scope :recently_launched, -> { where.not(last_launched_at: nil).order(last_launched_at: :desc) }
  scope :enabled, -> { where(enabled: true) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }

  # --- Validations ---
  validates :title, presence: true
  validates :estimated_minutes, numericality: { greater_than: 0 }, allow_nil: true

  # --- Instance Methods ---

  # Returns true if this idea was launched at any point today
  def launched_today?
    last_launched_at.present? && last_launched_at > Time.current.beginning_of_day
  end

  # Returns a display string like "x3" for launch count, or nil if never launched
  def launch_count_display
    times_launched.to_i > 0 ? "\u00d7#{times_launched}" : nil
  end
end
