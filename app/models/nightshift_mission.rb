# frozen_string_literal: true

class NightshiftMission < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true
  has_many :nightshift_selections, dependent: :destroy, inverse_of: :nightshift_mission

  belongs_to :user, optional: true, inverse_of: :nightshift_missions
  has_many :nightshift_selections, dependent: :destroy, inverse_of: :nightshift_mission, counter_cache: :selection_count

  validates :name, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :by_frequency, ->(freq) { where(frequency: freq) }
  scope :by_category, ->(cat) { where(category: cat) }

  FREQUENCIES = %w[always weekly one_time auto_generated manual].freeze
  CATEGORIES = %w[general infra security research code finance social network].freeze

  def due_tonight?
    return false unless enabled?

    case frequency
    when "always"
      true
    when "weekly"
      today_wday = Date.current.cwday # 1=Mon, 7=Sun
      (days_of_week || []).include?(today_wday)
    when "one_time"
      last_run_at.nil?
    when "auto_generated"
      last_run_at.nil? || last_run_at < 24.hours.ago
    when "manual"
      false
    else
      false
    end
  end

  # For backward compat with old mission hash format
  def to_mission_hash
    {
      id: id,
      title: name,
      desc: description,
      model: model,
      time: estimated_minutes,
      icon: icon,
      frequency: frequency,
      category: category,
      due_tonight: due_tonight?
    }
  end
end
