# frozen_string_literal: true

# WebSocket channel for real-time task status updates
# Broadcasts task changes to all connected clients
# Used alongside KanbanChannel for board-specific updates
class TaskUpdatesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "task_updates_#{current_user.id}"
    Rails.logger.info "[TaskUpdatesChannel] User #{current_user.id} subscribed"
  end

  def unsubscribed
    Rails.logger.info "[TaskUpdatesChannel] User #{current_user&.id} unsubscribed"
  end

  # Broadcast a task status change to the user
  def self.broadcast_task_change(user_id, task:, action: "updated", old_status: nil)
    ActionCable.server.broadcast(
      "task_updates_#{user_id}",
      {
        type: "task_#{action}",
        task_id: task.id,
        task_title: task.name,
        status: task.status,
        old_status: old_status,
        board_id: task.board_id,
        timestamp: Time.current.to_i
      }
    )
  end
end
