# frozen_string_literal: true

class RoadmapExecutorSyncService
  def initialize(board, markdown_content)
    @board = board
    @markdown_content = markdown_content
    @user = board.user
  end

  def sync!
    tasks = parse_markdown_checkboxes(@markdown_content)
    
    tasks.each do |task_data|
      existing_task = @board.tasks.find_by(name: task_data[:name])
      if existing_task
        if task_data[:completed] && existing_task.status != "done"
          existing_task.update!(status: "done")
        elsif !task_data[:completed] && existing_task.status == "done"
          existing_task.update!(status: "up_next")
        end
      else
        @board.tasks.create!(
          name: task_data[:name],
          user: @user,
          status: task_data[:completed] ? "done" : "up_next",
          description: "Auto-synced from Roadmap"
        )
      end
    end
  end

  private

  def parse_markdown_checkboxes(content)
    tasks = []
    content.each_line do |line|
      if line.match?(/^\s*-\s*\[([ xX])\]\s+(.+)$/)
        match = line.match(/^\s*-\s*\[([ xX])\]\s+(.+)$/)
        is_completed = match[1].downcase == "x"
        task_name = match[2].strip
        tasks << { name: task_name, completed: is_completed }
      end
    end
    tasks
  end
end
