# frozen_string_literal: true

# WebSocket channel for live chat between ClawTrol user and a running agent session.
#
# Subscribe with: { channel: "ChatChannel", task_id: <id> }
# Send messages:  { message: "Hello agent" }
#
# Broadcasts on stream "chat_task_<id>" with payloads:
#   { type: "message", role: "user"|"agent", content: "...", timestamp: <unix> }
#   { type: "status",  status: "sent"|"error", detail: "..." }
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @task_id = params[:task_id]

    task = current_user.tasks.find_by(id: @task_id)
    if task
      @task = task
      stream_from stream_name
      Rails.logger.info "[ChatChannel] User #{current_user.id} subscribed to task #{@task_id}"
    else
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "[ChatChannel] Unsubscribed from task #{@task_id}"
  end

  # Called when the frontend sends a message via ActionCable
  #   data: { "message" => "Hello agent" }
  def receive(data)
    message = data["message"].to_s.strip
    return if message.blank?

    # Broadcast the user's message immediately so it appears in the chat
    self.class.broadcast_message(@task_id, role: "user", content: message)

    # Send to gateway in a background thread to avoid blocking the channel
    task = @task
    Thread.new do
      begin
        client = OpenclawGatewayClient.new(task.user)
        session_key = "hook:chat:task-#{task.id}"
        result = client.sessions_send(session_key, message)

        if result["ok"]
          Rails.logger.info "[ChatChannel] Sent via hooks/agent, runId=#{result['runId']}"
          self.class.broadcast_status(@task_id, "sent", detail: "runId: #{result['runId']}")
        else
          self.class.broadcast_status(@task_id, "error", detail: result.to_s)
        end
      rescue => e
        Rails.logger.error "[ChatChannel] Failed to send: #{e.class}: #{e.message}"
        self.class.broadcast_status(@task_id, "error", detail: e.message)
      end
    end
  end

  # Broadcast a chat message to all subscribers of a task
  def self.broadcast_message(task_id, role:, content:)
    ActionCable.server.broadcast(
      "chat_task_#{task_id}",
      {
        type: "message",
        role: role,
        content: content,
        timestamp: Time.current.to_i
      }
    )
  end

  # Broadcast a status update (sent confirmation, errors, etc.)
  def self.broadcast_status(task_id, status, detail: nil)
    ActionCable.server.broadcast(
      "chat_task_#{task_id}",
      {
        type: "status",
        status: status,
        detail: detail,
        timestamp: Time.current.to_i
      }
    )
  end

  private

  def stream_name
    "chat_task_#{@task_id}"
  end
end
