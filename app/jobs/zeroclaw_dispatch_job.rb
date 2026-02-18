# frozen_string_literal: true

class ZeroclawDispatchJob < ApplicationJob
  queue_as :default

  def perform(task_id, agent_id)
    task = Task.find(task_id)
    agent = ZeroclawAgent.find(agent_id)

    message = task.description.to_s.presence || task.name.to_s

    result = agent.dispatch(message)
    agent.update_column(:last_seen_at, Time.current)

    dispatch_data = {
      "agent_name" => agent.name,
      "agent_url" => agent.url,
      "model" => result["model"],
      "response" => result["response"],
      "dispatched_at" => Time.current.iso8601
    }

    new_state = (task.state_data || {}).merge("zeroclaw_dispatch" => dispatch_data)
    append = "\n\n---\n\n## ZeroClaw Response (#{agent.name} · #{result['model']})\n\n#{result['response']}"
    task.update_columns(
      state_data: new_state,
      description: task.description.to_s + append,
      status: task.status == "up_next" ? Task.statuses[:in_progress] : task.status
    )
  rescue => e
    Rails.logger.error "[ZeroclawDispatchJob] Failed for task #{task_id}: #{e.message}"
  end
end
