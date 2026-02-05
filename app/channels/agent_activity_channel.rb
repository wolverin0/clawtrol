# frozen_string_literal: true

# WebSocket channel for real-time agent activity updates
# Clients subscribe to a specific task and receive notifications when agent transcript updates
# This replaces the 2.5-second polling for agent log updates
class AgentActivityChannel < ApplicationCable::Channel
  def subscribed
    @task_id = params[:task_id]
    
    # Verify task exists (we allow viewing agent logs publicly for now)
    task = Task.find_by(id: @task_id)
    if task
      stream_from stream_name
      Rails.logger.info "[AgentActivityChannel] Subscribed to task #{@task_id}"
    else
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "[AgentActivityChannel] Unsubscribed from task #{@task_id}"
  end

  # Class method to broadcast agent activity update
  # Call this when agent_complete is called or when activity is received
  def self.broadcast_activity(task_id, data = {})
    ActionCable.server.broadcast(
      "agent_activity_task_#{task_id}",
      {
        type: "activity",
        task_id: task_id,
        timestamp: Time.current.to_i
      }.merge(data)
    )
  end

  # Broadcast when task status changes (agent started, completed, etc)
  def self.broadcast_status(task_id, status, data = {})
    ActionCable.server.broadcast(
      "agent_activity_task_#{task_id}",
      {
        type: "status",
        task_id: task_id,
        status: status,
        timestamp: Time.current.to_i
      }.merge(data)
    )
  end

  private

  def stream_name
    "agent_activity_task_#{@task_id}"
  end
end
