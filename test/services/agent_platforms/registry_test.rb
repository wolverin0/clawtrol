# frozen_string_literal: true

require "test_helper"

class AgentPlatforms::RegistryTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
  end

  test "defaults to OpenclawAdapter when nothing is configured" do
    @user.update!(orchestration_mode: "openclaw_only", preferred_agent_platform: "openclaw")
    adapter = AgentPlatforms::Registry.for(@user)
    assert_instance_of AgentPlatforms::OpenclawAdapter, adapter
    assert_equal "openclaw", adapter.key
  end

  test "honors explicit platform override even if user prefers other" do
    @user.update!(orchestration_mode: "dual", preferred_agent_platform: "openclaw")
    adapter = AgentPlatforms::Registry.for(@user, platform: "hermes")
    assert_instance_of AgentPlatforms::HermesAdapter, adapter
  end

  test "falls back to openclaw on invalid platform key" do
    adapter = AgentPlatforms::Registry.for(@user, platform: "wat")
    assert_instance_of AgentPlatforms::OpenclawAdapter, adapter
  end

  test "uses preferred_agent_platform when no override" do
    @user.update!(orchestration_mode: "hermes_only", preferred_agent_platform: "hermes")
    adapter = AgentPlatforms::Registry.for(@user)
    assert_instance_of AgentPlatforms::HermesAdapter, adapter
  end

  test "enabled_platforms reflects orchestration_mode" do
    @user.orchestration_mode = "openclaw_only"
    assert_equal %w[openclaw], AgentPlatforms::Registry.enabled_platforms(@user)

    @user.orchestration_mode = "hermes_only"
    assert_equal %w[hermes], AgentPlatforms::Registry.enabled_platforms(@user)

    @user.orchestration_mode = "dual"
    assert_equal %w[openclaw hermes], AgentPlatforms::Registry.enabled_platforms(@user)
  end

  test "available_for returns adapters for each enabled platform" do
    @user.orchestration_mode = "dual"
    adapters = AgentPlatforms::Registry.available_for(@user)
    assert_equal %w[openclaw hermes], adapters.map(&:key)
  end

  test "explicit platform override is limited to enabled platforms" do
    @user.update!(orchestration_mode: "openclaw_only", preferred_agent_platform: "openclaw")

    adapter = AgentPlatforms::Registry.for(@user, platform: "hermes")

    assert_instance_of AgentPlatforms::OpenclawAdapter, adapter
    assert_equal "openclaw", adapter.key
  end

  test "uses enabled platform when preferred platform conflicts with only-mode" do
    @user.update!(orchestration_mode: "hermes_only", preferred_agent_platform: "openclaw")

    adapter = AgentPlatforms::Registry.for(@user)

    assert_instance_of AgentPlatforms::HermesAdapter, adapter
    assert_equal "hermes", adapter.key
  end
end
