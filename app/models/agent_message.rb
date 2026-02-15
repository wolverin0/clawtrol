# frozen_string_literal: true

class AgentMessage < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :task, inverse_of: :agent_messages
  belongs_to :source_task, class_name: "Task", optional: true, inverse_of: :inverse_dependencies

  DIRECTIONS = %w[incoming outgoing].freeze
  MESSAGE_TYPES = %w[output handoff feedback error].freeze

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :message_type, presence: true, inclusion: { in: MESSAGE_TYPES }
  validates :content, presence: true, length: { maximum: 100_000 }
  validates :summary, length: { maximum: 2000 }, allow_nil: true
  validates :sender_model, length: { maximum: 100 }, allow_nil: true
  validates :sender_session_id, length: { maximum: 200 }, allow_nil: true
  validates :sender_name, length: { maximum: 100 }, allow_nil: true

  # --- Scopes ---
  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :by_type, ->(type) { where(message_type: type) }
  scope :recent, ->(n = 20) { reverse_chronological.limit(n) }

  # --- Class Methods ---

  # Record an inter-agent message when one task's output feeds into another.
  # Called from HooksController on phase handoff or follow-up creation.
  def self.record_handoff!(from_task:, to_task:, content:, summary: nil, model: nil, session_id: nil, agent_name: nil, metadata: {})
    transaction do
      # Outgoing message on the source task
      from_task.agent_messages.create!(
        direction: "outgoing",
        source_task: to_task,
        content: content,
        summary: summary,
        message_type: "handoff",
        sender_model: model,
        sender_session_id: session_id,
        sender_name: agent_name,
        metadata: metadata.merge(target_task_id: to_task.id, target_task_name: to_task.name)
      )

      # Incoming message on the destination task
      to_task.agent_messages.create!(
        direction: "incoming",
        source_task: from_task,
        content: content,
        summary: summary,
        message_type: "handoff",
        sender_model: model,
        sender_session_id: session_id,
        sender_name: agent_name,
        metadata: metadata.merge(source_task_id: from_task.id, source_task_name: from_task.name)
      )
    end
  end

  # Record agent output as an incoming message on the task itself
  def self.record_output!(task:, content:, summary: nil, model: nil, session_id: nil, agent_name: nil, metadata: {})
    task.agent_messages.create!(
      direction: "incoming",
      message_type: "output",
      content: content,
      summary: summary,
      sender_model: model,
      sender_session_id: session_id,
      sender_name: agent_name,
      metadata: metadata
    )
  end

  # Record an error message
  def self.record_error!(task:, content:, model: nil, session_id: nil, agent_name: nil, metadata: {})
    task.agent_messages.create!(
      direction: "incoming",
      message_type: "error",
      content: content,
      sender_model: model,
      sender_session_id: session_id,
      sender_name: agent_name,
      metadata: metadata
    )
  end

  # --- Instance Methods ---

  def incoming?
    direction == "incoming"
  end

  def outgoing?
    direction == "outgoing"
  end

  def handoff?
    message_type == "handoff"
  end

  def truncated_content(max = 500)
    return content if content.length <= max
    "#{content[0...max]}…"
  end

  def linked_task
    source_task
  end

  def display_sender
    sender_name.presence || sender_model.presence || "Agent"
  end

  def display_icon
    case message_type
    when "handoff" then "🔄"
    when "output"  then "📤"
    when "feedback" then "💬"
    when "error"   then "❌"
    else "📨"
    end
  end
end
