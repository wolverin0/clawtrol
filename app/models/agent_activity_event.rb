# frozen_string_literal: true

class AgentActivityEvent < ApplicationRecord
  EVENT_TYPES = %w[heartbeat tool_call tool_result error final_summary message status].freeze
  LEVELS = %w[debug info warn error].freeze

  belongs_to :task

  validates :run_id, :source, :level, :event_type, :seq, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :level, inclusion: { in: LEVELS }
  validates :seq, numericality: { only_integer: true, greater_than: 0 }
  validates :run_id, uniqueness: { scope: :seq }

  scope :for_task, ->(task_id) { where(task_id: task_id) }
  scope :ordered, -> { order(:created_at, :seq, :id) }

  def as_agent_log_message
    role = case event_type
    when "tool_result" then "toolResult"
    when "tool_call" then "assistant"
    when "error" then "assistant"
    else "assistant"
    end

    content_item = case event_type
    when "tool_call"
      { type: "tool_call", name: payload["tool_name"] || payload["name"] || "tool" }
    when "tool_result"
      { type: "tool_result", text: message.to_s }
    when "heartbeat"
      { type: "text", text: "💓 #{message.presence || 'Heartbeat'}" }
    when "final_summary"
      { type: "text", text: "✅ #{message}" }
    when "error"
      { type: "text", text: "❌ #{message}" }
    else
      { type: "text", text: message.to_s }
    end

    {
      id: "evt-#{id}",
      line: seq,
      timestamp: created_at.iso8601,
      role: role,
      content: [content_item]
    }
  end
end
