# frozen_string_literal: true

require "test_helper"

class PersonaGeneratorServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
  end

  test "generates persona successfully for board with tasks" do
    task = @board.tasks.create!(
      user: @user,
      name: "Fix login bug",
      description: "Auth is broken",
      status: :inbox,
      tags: %w[bug fix],
      model: "opus"
    )

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_kind_of AgentPersona, result.persona
    assert result.persona.persisted?
    assert_equal @user, result.persona.user
    assert_equal @board.id, result.persona.board_id
    assert result.persona.auto_generated?
    assert result.persona.active?
    assert_includes result.persona.name, @board.name.parameterize
    assert_includes result.persona.system_prompt, @board.name
    assert_includes result.persona.system_prompt, "opus"
  end

  test "generates persona for empty board with defaults" do
    empty_board = @user.boards.create!(name: "Empty Board")

    result = PersonaGeneratorService.new(board: empty_board, user: @user).call

    assert result.success?
    assert_equal "sonnet", result.persona.model # default when no tasks
    assert_includes result.persona.description, "0 tasks analyzed"
  end

  test "determines fast-coding tier from tags" do
    @board.tasks.create!(user: @user, name: "Fix bug", status: :inbox, tags: %w[bug code])

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal "fast-coding", result.persona.tier
  end

  test "determines research tier from tags" do
    @board.tasks.create!(user: @user, name: "Analyze market", status: :inbox, tags: %w[research analysis])

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal "research", result.persona.tier
  end

  test "determines operations tier from tags" do
    @board.tasks.create!(user: @user, name: "Deploy infra", status: :inbox, tags: %w[infra deploy])

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal "operations", result.persona.tier
  end

  test "defaults to strategic-reasoning tier" do
    @board.tasks.create!(user: @user, name: "Plan roadmap", status: :inbox, tags: %w[planning strategy])

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal "strategic-reasoning", result.persona.tier
  end

  test "includes error tasks in system prompt" do
    @board.tasks.create!(
      user: @user,
      name: "Broken task",
      status: :inbox,
      error_message: "TypeError: cannot read property 'x' of undefined"
    )

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_includes result.persona.system_prompt, "Common Mistakes to Avoid"
    assert_includes result.persona.system_prompt, "TypeError"
  end

  test "updates existing auto-generated persona" do
    existing = AgentPersona.create!(
      user: @user,
      board: @board,
      name: "old-agent",
      auto_generated: true,
      tier: "research",
      active: true
    )

    @board.tasks.create!(user: @user, name: "New task", status: :inbox)

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal existing.id, result.persona.id # same record, updated
    assert_includes result.persona.name, @board.name.parameterize
  end

  test "uses board icon as persona emoji" do
    @board.update!(icon: "🔥")
    @board.tasks.create!(user: @user, name: "Test", status: :inbox)

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal "🔥", result.persona.emoji
  end

  test "picks most-used model as preferred" do
    3.times { @board.tasks.create!(user: @user, name: "Task", status: :inbox, model: "codex") }
    1.times { @board.tasks.create!(user: @user, name: "Task", status: :inbox, model: "opus") }

    result = PersonaGeneratorService.new(board: @board, user: @user).call

    assert result.success?
    assert_equal "codex", result.persona.model
  end
end
