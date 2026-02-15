class NightshiftMission < ApplicationRecord
  belongs_to :user, optional: true
  has_many :nightshift_selections, dependent: :destroy

  FREQUENCIES = %w[always weekly one_time auto_generated manual].freeze
  CATEGORIES = %w[general infra security research code finance social network].freeze
  VALID_MODELS = %w[gemini opus sonnet codex glm flash].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 10_000 }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :category, inclusion: { in: CATEGORIES }
  validates :model, inclusion: { in: VALID_MODELS }, allow_blank: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 480 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :icon, length: { maximum: 10 }
  validate :days_of_week_validity

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :by_frequency, ->(freq) { where(frequency: freq) }
  scope :by_category, ->(cat) { where(category: cat) }

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

  private

  def days_of_week_validity
    return if days_of_week.blank?
    unless days_of_week.is_a?(Array) && days_of_week.all? { |d| d.is_a?(Integer) && d.between?(1, 7) }
      errors.add(:days_of_week, "must be an array of integers 1-7 (Mon-Sun)")
    end
  end

  public

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
