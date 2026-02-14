# frozen_string_literal: true

require "test_helper"

class AgentPersonaTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
  end

  def build_persona(attrs = {})
    AgentPersona.new({
      name: "test-persona-#{SecureRandom.hex(4)}",
      user: @user,
      model: "opus",
      active: true
    }.merge(attrs))
  end

  # --- Validations ---
  test "valid with required fields" do
    p = build_persona
    assert p.valid?, p.errors.full_messages.join(", ")
  end

  test "requires name" do
    p = build_persona(name: nil)
    assert_not p.valid?
  end

  test "name unique per user" do
    build_persona(name: "unique-agent").save!
    dup = build_persona(name: "unique-agent")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "already exists for this user"
  end

  test "same name allowed for different users" do
    user2 = User.create!(email_address: "other@test.com", password: "password123456")
    build_persona(name: "shared-name", user: @user).save!
    p2 = build_persona(name: "shared-name", user: user2)
    assert p2.valid?
  end

  test "model validates inclusion" do
    p = build_persona(model: "gpt-99")
    assert_not p.valid?
  end

  test "model allows blank" do
    p = build_persona(model: "")
    assert p.valid?
  end

  test "fallback_model validates inclusion" do
    p = build_persona(fallback_model: "invalid")
    assert_not p.valid?
  end

  test "tier validates inclusion" do
    p = build_persona(tier: "invalid")
    assert_not p.valid?
  end

  test "user is optional (system persona)" do
    p = build_persona(user: nil, name: "system-persona")
    assert p.valid?
  end

  # --- Instance methods ---
  test "spawn_prompt includes name and description" do
    p = build_persona(name: "code-reviewer", description: "Reviews code for security issues")
    prompt = p.spawn_prompt
    assert_includes prompt, "Code Reviewer"
    assert_includes prompt, "Reviews code for security issues"
  end

  test "spawn_prompt includes system_prompt" do
    p = build_persona(system_prompt: "You are a security expert.")
    assert_includes p.spawn_prompt, "You are a security expert."
  end

  test "model_chain with both models" do
    p = build_persona(model: "opus", fallback_model: "codex")
    assert_equal "opus → codex", p.model_chain
  end

  test "model_chain with only primary" do
    p = build_persona(model: "opus", fallback_model: nil)
    assert_equal "opus", p.model_chain
  end

  test "tools_list handles array" do
    p = build_persona(tools: ["Read", "Write", "exec"])
    assert_equal ["Read", "Write", "exec"], p.tools_list
  end

  test "tools_list handles string" do
    p = build_persona(tools: "Read, Write, exec")
    assert_equal ["Read", "Write", "exec"], p.tools_list
  end

  test "tools_list handles nil" do
    p = build_persona(tools: nil)
    assert_equal [], p.tools_list
  end

  test "tier_color returns correct colors" do
    assert_equal "purple", build_persona(tier: "strategic-reasoning").tier_color
    assert_equal "blue", build_persona(tier: "fast-coding").tier_color
    assert_equal "green", build_persona(tier: "research").tier_color
    assert_equal "orange", build_persona(tier: "operations").tier_color
    assert_equal "gray", build_persona(tier: nil).tier_color
  end

  test "model_color returns correct colors" do
    assert_equal "purple", build_persona(model: "opus").model_color
    assert_equal "blue", build_persona(model: "codex").model_color
    assert_equal "emerald", build_persona(model: "gemini").model_color
    assert_equal "amber", build_persona(model: "glm").model_color
    assert_equal "orange", build_persona(model: "sonnet").model_color
  end

  # --- Scopes ---
  test "active scope" do
    p1 = build_persona(active: true)
    p1.save!
    p2 = build_persona(active: false)
    p2.save!
    assert_includes AgentPersona.active, p1
    assert_not_includes AgentPersona.active, p2
  end

  test "for_user includes nil and matching user_id" do
    system = build_persona(user: nil, name: "system-#{SecureRandom.hex(4)}")
    system.save!
    user_persona = build_persona(user: @user)
    user_persona.save!
    scoped = AgentPersona.for_user(@user)
    assert_includes scoped, system
    assert_includes scoped, user_persona
  end

  # --- Class methods ---
  test "emoji_for_name returns specific emojis" do
    assert_equal "🔍", AgentPersona.send(:emoji_for_name, "code-reviewer")
    assert_equal "🔒", AgentPersona.send(:emoji_for_name, "security-auditor")
    assert_equal "📚", AgentPersona.send(:emoji_for_name, "research-analyst")
    assert_equal "🤖", AgentPersona.send(:emoji_for_name, "unknown-agent")
  end

  # --- Associations ---
  test "has_many tasks with nullify" do
    p = build_persona
    p.save!
    board = Board.first || Board.create!(name: "Test Board", user: @user)
    task = Task.create!(name: "Test", board: board, user: @user, status: "inbox", agent_persona: p)
    assert_equal 1, p.tasks.count
    p.destroy
    task.reload
    assert_nil task.agent_persona_id
  end
end
