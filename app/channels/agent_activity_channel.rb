# frozen_string_literal: true

# WebSocket channel for real-time agent activity updates
# Clients subscribe to a specific task and receive notifications when agent transcript updates
# This replaces the 2.5-second polling for agent log updates
class AgentActivityChannel < ApplicationCable::Channel
  def subscribed
    @task_id = params[:task_id]
    @map_id = params[:map_id]

    # Verify task exists and belongs to the current user
    task = current_user ? Task.joins(:board).where(boards: { user_id: current_user.id }).find_by(id: @task_id) : nil
    unless task
      reject
      return
    end

    stream_from task_stream_name(@task_id)
    stream_from map_stream_name(@map_id) if @map_id.present?

    Rails.logger.info "[AgentActivityChannel] Subscribed task=#{@task_id} map=#{@map_id || '-'}"
  end

  def unsubscribed
    Rails.logger.info "[AgentActivityChannel] Unsubscribed task=#{@task_id} map=#{@map_id || '-'}"
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

  # Broadcast codemap events (state_sync, tile_patch, sprite_patch, camera, selection, debug_overlay)
  # Payload format follows docs/research/codemap-plan.md envelope expectations.
  def self.broadcast_codemap(task_id:, map_id:, event:, seq:, data: {})
    payload = {
      type: "codemap_event",
      task_id: task_id,
      map_id: map_id,
      event: event,
      seq: seq,
      data: data,
      timestamp: Time.current.to_i
    }

    ActionCable.server.broadcast(task_stream_name(task_id), payload)
    ActionCable.server.broadcast(map_stream_name(map_id), payload) if map_id.present?
  end

  def self.task_stream_name(task_id)
    "agent_activity_task_#{task_id}"
  end

  def self.map_stream_name(map_id)
    "agent_activity_map_#{map_id}"
  end

  private

  def task_stream_name(task_id)
    self.class.task_stream_name(task_id)
  end

  def map_stream_name(map_id)
    self.class.map_stream_name(map_id)
  end
end
