class TaskList < ApplicationRecord
  belongs_to :project
  belongs_to :user
  has_many :tasks, dependent: :destroy

  validates :title, presence: true

  before_create :set_position

  # Cached task counts to avoid N+1 queries
  def cached_task_count
    @task_count ||= tasks.count
  end

  def cached_completed_task_count
    @completed_task_count ||= tasks.completed.count
  end

  private

  def set_position
    self.position ||= 1
  end
end
