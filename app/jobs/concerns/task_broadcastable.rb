# frozen_string_literal: true

# Shared concern for jobs that need to broadcast task card updates
# via Turbo Streams after modifying task state.
#
# Usage:
#   class MyJob < ApplicationJob
#     include TaskBroadcastable
#     def perform(task_id)
#       task = Task.find(task_id)
#       # ... modify task ...
#       broadcast_task_update(task)
#     end
#   end
module TaskBroadcastable
  extend ActiveSupport::Concern

  private

  def broadcast_task_update(task)
    return unless task&.board_id

    Turbo::StreamsChannel.broadcast_action_to(
      "board_#{task.board_id}",
      action: :replace,
      target: "task_#{task.id}",
      partial: "boards/task_card",
      locals: { task: task }
    )

    # Also notify WebSocket clients for real-time kanban updates
    KanbanChannel.broadcast_refresh(task.board_id, task_id: task.id, action: "update")
  end
end
