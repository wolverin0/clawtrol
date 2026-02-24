# frozen_string_literal: true

class RoadmapExecutorSync
  def initialize(board_roadmap)
    @board_roadmap = board_roadmap
    @board = board_roadmap.board
    @user = @board.user
  end

  def call
    ApplicationRecord.transaction do
      @board_roadmap.unchecked_items.each do |item|
        sync_item(item[:key], item[:text])
      end
    end
  end

  private

  def sync_item(item_key, item_text)
    # Check if a link already exists
    link = @board_roadmap.task_links.find_by(item_key: item_key)
    return if link

    # Check if a task with the exact name already exists on this board
    # to avoid duplicates if the user created it manually.
    task = @board.tasks.find_by(name: item_text)

    unless task
      task = @board.tasks.create!(
        user: @user,
        name: item_text,
        status: "inbox"
      )
    end

    @board_roadmap.task_links.create!(
      item_key: item_key,
      item_text: item_text,
      task: task
    )
  end
end
