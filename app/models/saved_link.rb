class SavedLink < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, processing: 1, done: 2, failed: 3 }, default: :pending

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }
  validates :summary_file_path, length: { maximum: 1024 }, allow_blank: true

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
