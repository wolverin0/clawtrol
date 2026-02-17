# frozen_string_literal: true

require "test_helper"
require "securerandom"

class Api::V1::FactoryAgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "factory_agents_test@example.com", password: "password123")
    @token = ApiToken.create!(user: @user, name: "Test token")
    @headers = {
      "Authorization" => "Bearer #{@token.raw_token}",
      "Content-Type" => "application/json"
    }
  end

  test "index lists agents" do
    create_agent(slug: "index-agent-a")
    create_agent(slug: "index-agent-b")

    get "/api/v1/factory/agents", headers: @headers

    assert_response :success
    assert_operator response.parsed_body.size, :>=, 2
  end

  test "index filters by category" do
    create_agent(slug: "cat-dev", category: "development")
    create_agent(slug: "cat-qa", category: "qa")

    get "/api/v1/factory/agents", params: { category: "development" }, headers: @headers

    assert_response :success
    assert response.parsed_body.all? { |a| a["category"] == "development" }
  end

  test "index filters by builtin true false" do
    create_agent(slug: "builtin-true", builtin: true)
    create_agent(slug: "builtin-false", builtin: false)

    get "/api/v1/factory/agents", params: { builtin: true }, headers: @headers
    assert_response :success
    assert response.parsed_body.all? { |a| a["builtin"] == true }

    get "/api/v1/factory/agents", params: { builtin: false }, headers: @headers
    assert_response :success
    assert response.parsed_body.all? { |a| a["builtin"] == false }
  end

  test "show returns single agent" do
    agent = create_agent(slug: "show-agent")

    get "/api/v1/factory/agents/#{agent.id}", headers: @headers

    assert_response :success
    assert_equal agent.id, response.parsed_body["id"]
  end

  test "create makes custom agent with builtin false" do
    post "/api/v1/factory/agents",
         params: {
           name: "Custom Agent",
           slug: "custom-agent",
           category: "ops",
           source: "user",
           system_prompt: "Do custom work",
           description: "custom",
           tools_needed: [ "git", "rails" ],
           run_condition: "daily",
           cooldown_hours: 12,
           default_confidence_threshold: 75,
           priority: 3,
           builtin: true
         }.to_json,
         headers: @headers

    assert_response :created
    body = response.parsed_body
    assert_equal "Custom Agent", body["name"]
    assert_equal false, body["builtin"]

    created = FactoryAgent.find(body["id"])
    assert_equal false, created.builtin
  end

  test "create returns validation errors" do
    post "/api/v1/factory/agents", params: { slug: "invalid-agent" }.to_json, headers: @headers

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  test "update updates non builtin agent" do
    agent = create_agent(slug: "updatable-agent", builtin: false)

    patch "/api/v1/factory/agents/#{agent.id}",
          params: { description: "updated description", priority: 1 }.to_json,
          headers: @headers

    assert_response :success
    body = response.parsed_body
    assert_equal "updated description", body["description"]
    assert_equal 1, body["priority"]
  end

  test "update returns forbidden for builtin agent" do
    agent = create_agent(slug: "builtin-update", builtin: true)

    patch "/api/v1/factory/agents/#{agent.id}",
          params: { description: "should fail" }.to_json,
          headers: @headers

    assert_response :forbidden
  end

  private

  def create_agent(slug:, builtin: false, category: "general")
    FactoryAgent.create!(
      name: "Agent #{slug}",
      slug: slug,
      category: category,
      source: "system",
      system_prompt: "Prompt #{slug}",
      description: "Description #{slug}",
      tools_needed: [ "git" ],
      run_condition: "new_commits",
      cooldown_hours: 24,
      default_confidence_threshold: 80,
      priority: 5,
      builtin: builtin
    )
  end
end
