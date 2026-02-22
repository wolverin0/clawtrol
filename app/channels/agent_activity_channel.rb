# frozen_string_literal: true

# WebSocket channel for real-time agent activity updates
# Clients subscribe to a specific task and receive notifications when agent transcript updates
# This replaces the 2.5-second polling for agent log updates
class AgentActivityChannel < ApplicationCable::Channel
  def subscribed
    @task_id = params[:task_id]

    # Verify task exists and belongs to the current user
    task = current_user ? Task.joins(:board).where(boards: { user_id: current_user.id }).find_by(id: @task_id) : nil
    unless task
      reject
      return
    end

    stream_from task_stream_name(@task_id)

    Rails.logger.info "[AgentActivityChannel] Subscribed task=#{@task_id}"
  end

  def unsubscribed
    Rails.logger.info "[AgentActivityChannel] Unsubscribed task=#{@task_id}"
  end

  # Class method to broadcast agent activity update
  # Called by TranscriptWatcher when new messages are available
  def self.broadcast_activity(task_id, data = {})
    payload = {
      type: "activity",
      task_id: task_id,
      timestamp: Time.current.to_i
    }.merge(data)

    ActionCable.server.broadcast(task_stream_name(task_id), payload)

    if data[:messages].present?
      Rails.logger.debug "[AgentActivityChannel] Broadcast #{data[:messages].size} messages to task #{task_id}"
    end
  end

  # Broadcast when task status changes (agent started, completed, etc)
  def self.broadcast_status(task_id, status, data = {})
    ActionCable.server.broadcast(
      task_stream_name(task_id),
      {
        type: "status",
        task_id: task_id,
        status: status,
        timestamp: Time.current.to_i
      }.merge(data)
    )
  end

  def self.broadcast_runtime_event(task_id, event)
    payload = {
      type: "runtime_event",
      task_id: task_id,
      timestamp: Time.current.to_i
    }.merge(event || {})

    ActionCable.server.broadcast(task_stream_name(task_id), payload)
  end

  def self.broadcast_runtime_events(task_id, events)
    payload = {
      type: "runtime_events",
      task_id: task_id,
      events: Array(events),
      timestamp: Time.current.to_i
    }

    ActionCable.server.broadcast(task_stream_name(task_id), payload)
  end

  def self.task_stream_name(task_id)
    "agent_activity_task_#{task_id}"
  end

  private

  def task_stream_name(task_id)
    self.class.task_stream_name(task_id)
  end
end
