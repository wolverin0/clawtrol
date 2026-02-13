class FactoryLoop < ApplicationRecord
  has_many :factory_cycle_logs, dependent: :destroy

  STATUSES = %w[idle playing paused stopped error].freeze

  validates :name, :slug, :interval_ms, :model, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :interval_ms, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:name) }
  scope :by_status, ->(status) { where(status:) if status.present? }
  scope :playing, -> { where(status: "playing") }

  before_validation :normalize_slug

  def play!
    update!(status: "playing")
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
end
