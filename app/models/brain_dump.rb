class BrainDump < ApplicationRecord
  belongs_to :user

  validates :content, presence: true

  scope :pending, -> { where(processed: false) }
  scope :processed, -> { where(processed: true) }

  def triage_into_task(board_id: nil)
    transaction do
      task = Task.create!(
        user: user,
        board_id: board_id || user.boards.first.id,
        name: content.truncate(100),
        description: content,
        status: :inbox
      )
      update!(processed: true, metadata: metadata.merge(triaged_task_id: task.id))
      task
    end
  end
end
