# frozen_string_literal: true

require "test_helper"
require "securerandom"

class Api::V1::FactoryLoopAgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "factory_loop_agents_test@example.com", password: "password123")
    @other_user = User.create!(email_address: "factory_loop_agents_other@example.com", password: "password123")
    @token = ApiToken.create!(user: @user, name: "Test token")
    @headers = {
      "Authorization" => "Bearer #{@token.raw_token}",
      "Content-Type" => "application/json"
    }

    @loop = create_loop(@user, "main-loop")
    @other_loop = create_loop(@other_user, "other-loop")
    @agent = create_agent("loop-agent-primary")
    @second_agent = create_agent("loop-agent-secondary")
  end

  test "index lists loop agents with join fields" do
    FactoryLoopAgent.create!(
      factory_loop: @loop,
      factory_agent: @agent,
      enabled: true,
      cooldown_hours_override: 8,
      confidence_threshold_override: 70
    )

    get "/api/v1/factory/loops/#{@loop.id}/agents", headers: @headers

    assert_response :success
    body = response.parsed_body
    assert_equal 1, body.size
    assert_equal @agent.id, body.first["id"]
    assert_equal true, body.first["enabled"]
    assert_equal 8, body.first["cooldown_hours_override"]
    assert_equal 70, body.first["confidence_threshold_override"]
  end

  test "index does not allow accessing another users loop" do
    get "/api/v1/factory/loops/#{@other_loop.id}/agents", headers: @headers

    assert_response :not_found
  end

  test "enable creates join if missing" do
    assert_difference "FactoryLoopAgent.count", 1 do
      post "/api/v1/factory/loops/#{@loop.id}/agents/#{@agent.id}/enable", headers: @headers
    end

    assert_response :success
    join = FactoryLoopAgent.find_by!(factory_loop: @loop, factory_agent: @agent)
    assert_equal true, join.enabled
  end

  test "enable sets existing join enabled true" do
    join = FactoryLoopAgent.create!(factory_loop: @loop, factory_agent: @agent, enabled: false)

    post "/api/v1/factory/loops/#{@loop.id}/agents/#{@agent.id}/enable", headers: @headers

    assert_response :success
    assert_equal true, join.reload.enabled
  end

  test "disable sets enabled false" do
    join = FactoryLoopAgent.create!(factory_loop: @loop, factory_agent: @agent, enabled: true)

    post "/api/v1/factory/loops/#{@loop.id}/agents/#{@agent.id}/disable", headers: @headers

    assert_response :success
    assert_equal false, join.reload.enabled
  end

  test "disable returns not found when join missing" do
    post "/api/v1/factory/loops/#{@loop.id}/agents/#{@second_agent.id}/disable", headers: @headers

    assert_response :not_found
  end

  test "update changes overrides" do
    join = FactoryLoopAgent.create!(factory_loop: @loop, factory_agent: @agent, enabled: true)

    patch "/api/v1/factory/loops/#{@loop.id}/agents/#{@agent.id}",
          params: { cooldown_hours_override: 10, confidence_threshold_override: 65 }.to_json,
          headers: @headers

    assert_response :success
    join.reload
    assert_equal 10, join.cooldown_hours_override
    assert_equal 65, join.confidence_threshold_override
  end

  test "update returns not found for another users loop" do
    FactoryLoopAgent.create!(factory_loop: @other_loop, factory_agent: @agent, enabled: true)

    patch "/api/v1/factory/loops/#{@other_loop.id}/agents/#{@agent.id}",
          params: { cooldown_hours_override: 10 }.to_json,
          headers: @headers

    assert_response :not_found
  end

  private

  def create_agent(slug)
    FactoryAgent.create!(
      name: "Agent #{slug}",
      slug: slug,
      category: "general",
      source: "system",
      system_prompt: "Prompt #{slug}",
      description: "Description #{slug}",
      tools_needed: [ "git" ],
      run_condition: "new_commits",
      cooldown_hours: 24,
      default_confidence_threshold: 80,
      priority: 5,
      builtin: false
    )
  end

  def create_loop(user, slug)
    FactoryLoop.create!(
      user: user,
      name: "Loop #{slug}",
      slug: slug,
      interval_ms: 60000,
      model: "claude-sonnet-4-5",
      status: "idle"
    )
  end
end
