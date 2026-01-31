class Comment < ApplicationRecord
  belongs_to :task, counter_cache: true

  validates :body, presence: true
  validates :author_type, presence: true, inclusion: { in: %w[user agent] }
  validates :author_name, presence: true

  # Activity source tracking (web vs api)
  attr_accessor :activity_source

  after_create :update_task_reply_status

  # Real-time broadcasts to user's board (only for API/background changes)
  # Skip broadcasts when activity_source is "web" since turbo_stream templates handle it
  after_create_commit :broadcast_create, unless: -> { activity_source == "web" }

  default_scope { order(created_at: :asc) }

  private

  # When a user comments, mark task as needing agent reply
  # When agent comments, clear the flag
  def update_task_reply_status
    task.update_column(:needs_agent_reply, author_type == "user")
  end

  def broadcast_create
    stream = "user_#{task.user_id}_board"

    # Remove "No comments yet" message if this is the first comment
    if task.comments.count == 1
      Turbo::StreamsChannel.broadcast_action_to(stream, action: :remove, target: "task-#{task.id}-no-comments")
    end

    # Append the new comment
    Turbo::StreamsChannel.broadcast_action_to(
      stream,
      action: :append,
      target: "task-#{task.id}-comments-list",
      partial: "shared/comment",
      locals: { comment: self }
    )

    # Update the task card to show new comment count
    task.reload
    Turbo::StreamsChannel.broadcast_action_to(
      stream,
      action: :replace,
      target: "task_#{task.id}",
      partial: "board/task_card",
      locals: { task: task }
    )
  end
end
