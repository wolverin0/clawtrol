# frozen_string_literal: true

class SavedLink < ApplicationRecord
  belongs_to :user, inverse_of: :user

  enum :status, { pending: 0, processing: 1, done: 2, failed: 3 }, default: :pending

  validates :url, presence: true, length: { maximum: 2048 },
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" },
            uniqueness: { scope: :user_id, message: "has already been saved" }
  validates :note, length: { maximum: 500 }, allow_nil: true
  validates :summary, length: { maximum: 50_000 }, allow_nil: true
  validates :raw_content, length: { maximum: 500_000 }, allow_nil: true
  validates :error_message, length: { maximum: 5000 }, allow_nil: true
  validates :source_type, inclusion: { in: %w[article youtube x reddit] }, allow_nil: true

  before_validation :detect_source_type, if: -> { source_type.blank? && url.present? }

  scope :newest_first, -> { order(created_at: :desc) }
  scope :unprocessed, -> { where(status: [:pending, :processing]) }

  private

  def detect_source_type
    uri = URI.parse(url) rescue nil
    return self.source_type = "article" unless uri

    host = uri.host&.downcase&.gsub(/\Awww\./, "")
    self.source_type = case host
    when /youtube\.com|youtu\.be/ then "youtube"
    when /x\.com|twitter\.com/ then "x"
    when /reddit\.com/ then "reddit"
    else "article"
    end
  end
end
