require "test_helper"

class FactoryLoopAgentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "test-la@example.com", password: "password123")
    @loop = FactoryLoop.create!(name: "Test Loop", slug: "test-loop-la", interval_ms: 60000, model: "flash", status: "idle", user: @user)
    @agent = FactoryAgent.create!(name: "Test Agent", slug: "test-agent-la", system_prompt: "test", run_condition: "always", cooldown_hours: 12, default_confidence_threshold: 70)
    @loop_agent = FactoryLoopAgent.new(factory_loop: @loop, factory_agent: @agent)
  end

  test "valid with required associations" do
    assert @loop_agent.valid?
  end

  test "uniqueness of agent per loop" do
    @loop_agent.save!
    dup = FactoryLoopAgent.new(factory_loop: @loop, factory_agent: @agent)
    assert_not dup.valid?
  end

  test "cooldown_hours_override must be non-negative" do
    @loop_agent.cooldown_hours_override = -1
    assert_not @loop_agent.valid?
  end

  test "confidence_threshold_override in 0-100 range" do
    @loop_agent.confidence_threshold_override = 150
    assert_not @loop_agent.valid?
  end

  test "effective_cooldown_hours uses override when present" do
    @loop_agent.cooldown_hours_override = 6
    assert_equal 6, @loop_agent.effective_cooldown_hours
  end

  test "effective_cooldown_hours falls back to agent default" do
    assert_equal 12, @loop_agent.effective_cooldown_hours
  end

  test "effective_confidence_threshold cascades correctly" do
    # Loop value wins over agent default when present
    expected_initial = @loop.confidence_threshold || 70
    assert_equal expected_initial, @loop_agent.effective_confidence_threshold
    # Loop override
    @loop.update!(confidence_threshold: 85)
    assert_equal 85, @loop_agent.effective_confidence_threshold
    # Direct override wins
    @loop_agent.confidence_threshold_override = 95
    assert_equal 95, @loop_agent.effective_confidence_threshold
  end

  test "scopes enabled and disabled" do
    @loop_agent.save!
    disabled = FactoryLoopAgent.create!(factory_loop: @loop, factory_agent: FactoryAgent.create!(name: "Other", slug: "other-la", system_prompt: "x", run_condition: "daily"), enabled: false)
    assert_includes FactoryLoopAgent.enabled, @loop_agent
    assert_includes FactoryLoopAgent.disabled, disabled
  end
end
