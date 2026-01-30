class Project < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy
  has_one :task_list, dependent: :destroy
  has_one_attached :image

  validates :title, presence: true

  validate :acceptable_image, if: :image_changed?

  before_create :set_position
  after_create :create_default_task_list

  default_scope { order(position: :asc) }

  scope :visible, -> { where(inbox: false) }
  scope :inbox_only, -> { where(inbox: true) }

  def inbox?
    inbox
  end

  def image_url
    image.attached? ? image : "defaultavatar.png"
  end

  # Cached task counts to avoid N+1 queries
  def cached_task_count
    @task_count ||= tasks.count
  end

  def cached_completed_task_count
    @completed_task_count ||= tasks.where(completed: true).count
  end

  # Ensure there's always a task list for this project
  def default_task_list
    task_list || create_task_list!(title: "Tasks", user_id: user_id, position: 1)
  end

  private

  def set_position
    return if inbox?
    max_position = user.projects.visible.maximum(:position) || 0
    self.position = max_position + 1
  end

  def create_default_task_list
    title = inbox? ? "Inbox" : "Tasks"
    create_task_list!(title: title, user_id: user_id, position: 1)
  end

  def image_changed?
    image.attached? && image.attachment.new_record?
  end

  def acceptable_image
    return unless image.attached?
    return unless image.blob.present?

    # Check file size
    unless image.blob.byte_size <= 512.kilobytes
      errors.add(:image, "is too large (maximum is 512KB)")
    end

    # Check content type
    acceptable_types = [ "image/jpeg", "image/jpg", "image/png", "image/webp" ]
    unless acceptable_types.include?(image.blob.content_type)
      errors.add(:image, "must be a JPEG, PNG, or WebP")
    end

    # Check dimensions only if the image is representable and metadata exists
    return unless image.blob.representable?
    return unless image.blob.metadata.present?

    metadata = image.blob.metadata
    width = metadata[:width]
    height = metadata[:height]

    # Only validate if dimensions are actually present in metadata
    if width.present? && height.present? && (width > 256 || height > 256)
      errors.add(:image, "dimensions must not exceed 256x256 pixels")
    end
  end
end
