class FactoryLoop < ApplicationRecord
  has_many :factory_cycle_logs, dependent: :destroy

  STATUSES = %w[idle playing paused stopped error error_paused].freeze

  validates :name, :slug, :interval_ms, :model, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :interval_ms, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:name) }
  scope :by_status, ->(status) { where(status:) if status.present? }
  scope :playing, -> { where(status: "playing") }

  # Status query methods
  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  before_validation :normalize_slug
  after_commit :sync_engine, if: :saved_change_to_status?

  def play!
    update!(status: "playing", last_cycle_at: nil, consecutive_failures: 0)
  end

  def pause!
    update!(status: "paused")
  end

  def stop!
    update!(status: "stopped", state: {})
  end

  def as_json(options = {})
    super(options.merge(include: { factory_cycle_logs: { only: [ :id, :cycle_number, :status, :started_at, :finished_at, :duration_ms, :summary ] } }))
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end

  def sync_engine
    if status == "playing"
      FactoryEngineService.new.start_loop(self)
    elsif %w[paused stopped idle error error_paused].include?(status)
      FactoryEngineService.new.stop_loop(self)
    end
  end
end
