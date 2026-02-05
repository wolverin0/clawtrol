# frozen_string_literal: true

# WebSocket channel for real-time Kanban board updates
# Clients subscribe to a specific board and receive notifications when tasks change
# This replaces the 15-second polling for board fingerprint changes
class KanbanChannel < ApplicationCable::Channel
  def subscribed
    @board_id = params[:board_id]
    
    # Verify user owns this board
    board = current_user.boards.find_by(id: @board_id)
    if board
      stream_from stream_name
      Rails.logger.info "[KanbanChannel] User #{current_user.id} subscribed to board #{@board_id}"
    else
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "[KanbanChannel] User #{current_user&.id} unsubscribed from board #{@board_id}"
  end

  # Class method to broadcast a board update
  # Call this when tasks are created, updated, or destroyed
  def self.broadcast_refresh(board_id, task_id: nil, action: "refresh")
    ActionCable.server.broadcast(
      "kanban_board_#{board_id}",
      {
        type: action,
        task_id: task_id,
        timestamp: Time.current.to_i
      }
    )
  end

  private

  def stream_name
    "kanban_board_#{@board_id}"
  end
end
