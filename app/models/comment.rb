class Comment < ApplicationRecord
  belongs_to :task, counter_cache: true

  validates :body, presence: true
  validates :author_type, presence: true, inclusion: { in: %w[user agent] }
  validates :author_name, presence: true

  after_create :update_task_reply_status

  default_scope { order(created_at: :asc) }

  private

  # When a user comments, mark task as needing agent reply
  # When agent comments, clear the flag
  def update_task_reply_status
    task.update_column(:needs_agent_reply, author_type == "user")
  end
end
