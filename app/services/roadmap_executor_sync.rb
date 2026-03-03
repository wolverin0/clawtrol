# frozen_string_literal: true

class RoadmapExecutorSync
  def initialize(board_roadmap)
    @board_roadmap = board_roadmap
    @board = board_roadmap.board
    @user = @board.user
  end

  def call
    items = @board_roadmap.unchecked_items
    return if items.empty?

    existing_links = preload_links(items)
    tasks_by_name = preload_tasks(items)

    ApplicationRecord.transaction do
      items.each do |item|
        next if existing_links.key?(item[:key])

        task = tasks_by_name[item[:text]] ||= create_task(item[:text])
        link = @board_roadmap.task_links.create!(item_key: item[:key], item_text: item[:text], task: task)
        existing_links[item[:key]] = link
      end
    end
  end

  private

  def preload_links(items)
    keys = items.map { |item| item[:key] }
    @board_roadmap.task_links.where(item_key: keys).index_by(&:item_key)
  end

  def preload_tasks(items)
    names = items.map { |item| item[:text] }
    @board.tasks.where(name: names).index_by(&:name)
  end

  def create_task(item_text)
    @board.tasks.create!(user: @user, name: item_text, status: "inbox")
  end
end
