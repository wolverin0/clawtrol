class Task < ApplicationRecord
  belongs_to :user
  has_many :activities, class_name: "TaskActivity", dependent: :destroy
  has_many :comments, dependent: :destroy

  enum :priority, { none: 0, low: 1, medium: 2, high: 3 }, default: :none, prefix: true
  enum :status, { inbox: 0, up_next: 1, in_progress: 2, in_review: 3, done: 4 }, default: :inbox

  validates :name, presence: true
  validates :priority, inclusion: { in: priorities.keys }
  validates :status, inclusion: { in: statuses.keys }

  # Activity tracking
  attr_accessor :activity_source
  after_create :record_creation_activity
  after_update :record_update_activities

  # Position management - acts_as_list functionality without the gem
  before_create :set_position
  before_update :save_original_position, if: :will_save_change_to_completed?
  before_update :track_completion_time, if: :will_save_change_to_completed?

  # Order incomplete tasks by position, completed tasks by completion time (most recent first)
  scope :incomplete, -> { where(completed: false).reorder(position: :asc) }
  scope :completed, -> { where(completed: true).reorder(completed_at: :desc) }
  default_scope { order(completed: :asc, position: :asc) }

  private

  def set_position
    return if position.present?

    # Prepend: shift all existing tasks down and insert at position 1
    user.tasks.where(status: status).update_all("position = position + 1")
    self.position = 1
  end

  def save_original_position
    # Save position before completing, clear when uncompleting
    if completed_changed? && completed?
      self.original_position = position_was
    elsif completed_changed? && !completed?
      # When uncompleting, we'll use original_position to restore, then clear it
      # This is handled in the controller
    end
  end

  def track_completion_time
    if completed_changed? && completed?
      self.completed_at = Time.current
    elsif completed_changed? && !completed?
      self.completed_at = nil
    end
  end

  def record_creation_activity
    TaskActivity.record_creation(self, source: activity_source || "web")
  end

  def record_update_activities
    source = activity_source || "web"

    # Track completion changes
    if saved_change_to_completed?
      TaskActivity.record_completion(self, completed: completed, source: source)
    end

    # Track field changes
    tracked_changes = saved_changes.slice(*TaskActivity::TRACKED_FIELDS)
    TaskActivity.record_changes(self, tracked_changes, source: source) if tracked_changes.any?
  end
end
