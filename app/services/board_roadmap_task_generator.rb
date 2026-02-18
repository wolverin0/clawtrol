# frozen_string_literal: true

class BoardRoadmapTaskGenerator
  Result = Struct.new(:created_tasks, :created_count, keyword_init: true)

  def initialize(board_roadmap)
    @roadmap = board_roadmap
    @board = board_roadmap.board
  end

  def call
    created = []

    BoardRoadmap.transaction do
      @roadmap.unchecked_items.each do |item|
        next if @roadmap.task_links.exists?(item_key: item[:key])

        task = @board.tasks.create!(
          name: item[:text],
          user: @board.user,
          status: :inbox
        )

        @roadmap.task_links.create!(
          task: task,
          item_key: item[:key],
          item_text: item[:text]
        )

        created << task
      end

      @roadmap.update!(
        last_generated_at: Time.current,
        last_generated_count: created.size
      )
    end

    Result.new(created_tasks: created, created_count: created.size)
  end
end
