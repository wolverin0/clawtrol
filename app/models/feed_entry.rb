# frozen_string_literal: true

class FeedEntry < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :feed_entries

  enum :status, { unread: 0, read: 1, saved: 2, dismissed: 3 }, default: :unread

  validates :feed_name, presence: true, length: { maximum: 100 }
  validates :title, presence: true, length: { maximum: 500 }
  validates :url, presence: true, length: { maximum: 2048 },
    format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }
  validates :url, uniqueness: true
  validates :relevance_score, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }, allow_nil: true
  validates :summary, length: { maximum: 10_000 }, allow_nil: true
  validates :content, length: { maximum: 100_000 }, allow_nil: true
  validates :author, length: { maximum: 200 }, allow_nil: true

  scope :newest_first, -> { order(published_at: :desc, created_at: :desc) }
  scope :high_relevance, -> { where("relevance_score >= ?", 0.7) }
  scope :by_feed, ->(name) { where(feed_name: name) }
  scope :recent, ->(days = 7) { where("published_at >= ? OR created_at >= ?", days.days.ago, days.days.ago) }
  scope :unread_or_saved, -> { where(status: [:unread, :saved]) }

  before_save :set_read_at, if: -> { status_changed? && read? }

  def high_relevance?
    relevance_score.present? && relevance_score >= 0.7
  end

  def relevance_label
    return "unknown" unless relevance_score
    case relevance_score
    when 0.8..1.0 then "high"
    when 0.5...0.8 then "medium"
    else "low"
    end
  end

  def time_ago
    return "unknown" unless published_at
    seconds = Time.current - published_at
    case seconds
    when 0...60 then "just now"
    when 60...3600 then "#{(seconds / 60).to_i}m ago"
    when 3600...86400 then "#{(seconds / 3600).to_i}h ago"
    else "#{(seconds / 86400).to_i}d ago"
    end
  end

  private

  def set_read_at
    self.read_at = Time.current
  end
end
