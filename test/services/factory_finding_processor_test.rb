# frozen_string_literal: true

require "test_helper"

class FactoryFindingProcessorTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "finding-processor-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @loop = FactoryLoop.create!(
      user: @user,
      name: "Finding Loop",
      slug: "finding-loop-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "flash",
      status: "idle",
      confidence_threshold: 90,
      max_findings_per_run: 5
    )
    @agent = FactoryAgent.create!(
      name: "Finding Agent",
      slug: "finding-agent-#{SecureRandom.hex(4)}",
      category: "testing",
      source: "system",
      system_prompt: "test",
      run_condition: "always",
      default_confidence_threshold: 80,
      cooldown_hours: 0,
      priority: 5
    )

    @board = Board.create!(
      user: @user,
      name: "Factory v2",
      icon: "🏭",
      color: "blue"
    )

    @loop.update!(config: { "board_id_for_findings" => @board.id })

    @run = FactoryAgentRun.create!(
      factory_loop: @loop,
      factory_agent: @agent,
      status: "clean",
      findings: []
    )
  end

  test "processes findings by confidence bands and creates task for auto-added finding" do
    @run.update!(findings: [
      { "description" => "Low confidence", "confidence" => 20 },
      { "description" => "Needs visibility", "confidence" => 50 },
      { "description" => "Needs review", "confidence" => 75 },
      { "description" => "Must auto add", "confidence" => 95 }
    ])

    processed = nil
    assert_difference -> { Task.where(board_id: @board.id, user_id: @user.id).count }, 1 do
      processed = FactoryFindingProcessor.new(@run).process!
    end

    assert_equal 4, processed.length
    assert_equal %w[discarded visible flagged auto_added], processed.map { |f| f["action"] }

    @run.reload
    assert_equal 3, @run.findings_count
    assert_equal "findings", @run.status

    task = Task.where(board_id: @board.id, user_id: @user.id).order(:id).last
    assert task.present?
    assert_includes task.tags, "factory-finding"
    assert_includes task.description, "Confidence: 95"
  end

  test "marks finding as duplicate when similar task already exists" do
    Task.create!(
      name: "Refactor flaky test retries in CI",
      description: "existing",
      tags: ["testing"],
      board_id: @board.id,
      status: :inbox,
      user: @user
    )

    @run.update!(findings: [
      { "description" => "Refactor flaky test retries for ci", "confidence" => 95 }
    ])

    processed = FactoryFindingProcessor.new(@run).process!

    assert_equal "duplicate", processed.first["action"]
    assert_equal 1, Task.where(board_id: @board.id, user_id: @user.id).count
  end

  test "suppresses finding when pattern is already suppressed" do
    normalized = "same repeated issue"
    FactoryFindingPattern.create!(
      factory_loop: @loop,
      pattern_hash: Digest::SHA256.hexdigest(normalized),
      description: "Same repeated issue",
      category: "testing",
      dismiss_count: 2,
      suppressed: true
    )

    @run.update!(findings: [
      { "description" => "Same repeated issue", "confidence" => 95 }
    ])

    processed = FactoryFindingProcessor.new(@run).process!

    assert_equal "suppressed", processed.first["action"]
    assert_equal 0, Task.where(board_id: @board.id, user_id: @user.id).count
  end

  test "caps processing to max_findings_per_run" do
    @loop.update!(max_findings_per_run: 2)
    @run.update!(findings: [
      { "description" => "one", "confidence" => 50 },
      { "description" => "two", "confidence" => 60 },
      { "description" => "three", "confidence" => 95 }
    ])

    processed = FactoryFindingProcessor.new(@run).process!

    assert_equal 2, processed.size
    assert_equal %w[visible visible], processed.map { |f| f["action"] }
  end
end
