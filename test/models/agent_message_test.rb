# frozen_string_literal: true

require "test_helper"

class AgentMessageTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @board = Board.first || Board.create!(name: "Test Board", user: @user)
    @task = Task.create!(name: "Source task", board: @board, user: @user, status: "in_progress")
    @target_task = Task.create!(name: "Target task", board: @board, user: @user, status: "inbox")
  end

  # --- Validations ---
  test "valid with all required fields" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "output", content: "Hello from agent")
    assert msg.valid?
  end

  test "requires task" do
    msg = AgentMessage.new(direction: "incoming", message_type: "output", content: "test")
    assert_not msg.valid?
    assert_includes msg.errors[:task], "must exist"
  end

  test "requires direction" do
    msg = AgentMessage.new(task: @task, direction: nil, message_type: "output", content: "test")
    assert_not msg.valid?
  end

  test "validates direction inclusion" do
    msg = AgentMessage.new(task: @task, direction: "sideways", message_type: "output", content: "test")
    assert_not msg.valid?
    assert_includes msg.errors[:direction], "is not included in the list"
  end

  test "validates message_type inclusion" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "gossip", content: "test")
    assert_not msg.valid?
    assert_includes msg.errors[:message_type], "is not included in the list"
  end

  test "requires content" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "output", content: nil)
    assert_not msg.valid?
    assert_includes msg.errors[:content], "can't be blank"
  end

  test "validates content max length" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "output", content: "x" * 100_001)
    assert_not msg.valid?
  end

  test "validates summary max length" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "output", content: "test", summary: "x" * 2001)
    assert_not msg.valid?
  end

  test "validates sender_model max length" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "output", content: "test", sender_model: "x" * 101)
    assert_not msg.valid?
  end

  test "source_task is optional" do
    msg = AgentMessage.new(task: @task, direction: "incoming", message_type: "output", content: "test", source_task: nil)
    assert msg.valid?
  end

  test "source_task belongs_to task" do
    msg = AgentMessage.create!(task: @task, source_task: @target_task, direction: "incoming", message_type: "handoff", content: "from target")
    assert_equal @target_task, msg.source_task
  end

  # --- Scopes ---
  test "chronological scope orders by created_at asc" do
    m1 = AgentMessage.create!(task: @task, direction: "incoming", message_type: "output", content: "first")
    m2 = AgentMessage.create!(task: @task, direction: "outgoing", message_type: "handoff", content: "second")
    assert_equal [m1, m2], @task.agent_messages.chronological.to_a
  end

  test "incoming scope" do
    AgentMessage.create!(task: @task, direction: "incoming", message_type: "output", content: "in")
    AgentMessage.create!(task: @task, direction: "outgoing", message_type: "handoff", content: "out")
    assert_equal 1, @task.agent_messages.incoming.count
  end

  test "outgoing scope" do
    AgentMessage.create!(task: @task, direction: "incoming", message_type: "output", content: "in")
    AgentMessage.create!(task: @task, direction: "outgoing", message_type: "handoff", content: "out")
    assert_equal 1, @task.agent_messages.outgoing.count
  end

  test "by_type scope" do
    AgentMessage.create!(task: @task, direction: "incoming", message_type: "output", content: "out")
    AgentMessage.create!(task: @task, direction: "incoming", message_type: "error", content: "err")
    assert_equal 1, @task.agent_messages.by_type("error").count
  end

  test "recent scope returns reverse chronological with limit" do
    5.times { |i| AgentMessage.create!(task: @task, direction: "incoming", message_type: "output", content: "msg #{i}") }
    recent = @task.agent_messages.recent(3)
    assert_equal 3, recent.count
    assert recent.first.created_at >= recent.last.created_at
  end

  # --- Class methods ---
  test "record_handoff! creates two messages" do
    assert_difference "AgentMessage.count", 2 do
      AgentMessage.record_handoff!(
        from_task: @task,
        to_task: @target_task,
        content: "Handoff content",
        summary: "Short summary",
        model: "opus",
        session_id: "sess-123",
        agent_name: "CodeReviewer"
      )
    end

    outgoing = @task.agent_messages.outgoing.last
    assert_equal "handoff", outgoing.message_type
    assert_equal @target_task, outgoing.source_task
    assert_equal "opus", outgoing.sender_model
    assert_equal "CodeReviewer", outgoing.sender_name

    incoming = @target_task.agent_messages.incoming.last
    assert_equal "handoff", incoming.message_type
    assert_equal @task, incoming.source_task
  end

  test "record_output! creates one message" do
    assert_difference "AgentMessage.count", 1 do
      AgentMessage.record_output!(
        task: @task,
        content: "Agent finished the task",
        model: "codex",
        session_id: "sess-456"
      )
    end

    msg = @task.agent_messages.last
    assert_equal "incoming", msg.direction
    assert_equal "output", msg.message_type
    assert_equal "codex", msg.sender_model
  end

  test "record_error! creates an error message" do
    AgentMessage.record_error!(
      task: @task,
      content: "Rate limit exceeded",
      model: "gemini"
    )

    msg = @task.agent_messages.last
    assert_equal "error", msg.message_type
    assert_equal "gemini", msg.sender_model
  end

  # --- Instance methods ---
  test "incoming? and outgoing?" do
    msg = AgentMessage.new(direction: "incoming")
    assert msg.incoming?
    assert_not msg.outgoing?
  end

  test "handoff?" do
    msg = AgentMessage.new(message_type: "handoff")
    assert msg.handoff?
  end

  test "truncated_content" do
    msg = AgentMessage.new(content: "a" * 600)
    assert_equal 501, msg.truncated_content(500).length # 500 + "…"
  end

  test "truncated_content returns full if short" do
    msg = AgentMessage.new(content: "short")
    assert_equal "short", msg.truncated_content(500)
  end

  test "display_sender prefers name over model" do
    msg = AgentMessage.new(sender_name: "CodeBot", sender_model: "opus")
    assert_equal "CodeBot", msg.display_sender
  end

  test "display_sender falls back to model" do
    msg = AgentMessage.new(sender_model: "codex")
    assert_equal "codex", msg.display_sender
  end

  test "display_sender falls back to Agent" do
    msg = AgentMessage.new
    assert_equal "Agent", msg.display_sender
  end

  test "display_icon per message_type" do
    assert_equal "🔄", AgentMessage.new(message_type: "handoff").display_icon
    assert_equal "📤", AgentMessage.new(message_type: "output").display_icon
    assert_equal "💬", AgentMessage.new(message_type: "feedback").display_icon
    assert_equal "❌", AgentMessage.new(message_type: "error").display_icon
  end

  # --- Associations ---
  test "task has_many agent_messages with dependent destroy" do
    AgentMessage.create!(task: @task, direction: "incoming", message_type: "output", content: "test")
    assert_equal 1, @task.agent_messages.count
    @task.destroy
    assert_equal 0, AgentMessage.where(task_id: @task.id).count
  end
end
