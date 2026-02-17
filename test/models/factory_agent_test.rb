require "test_helper"

class FactoryAgentTest < ActiveSupport::TestCase
  def setup
    @agent = FactoryAgent.new(
      name: "Security Auditor",
      slug: "security-auditor",
      system_prompt: "You are a security auditor.",
      run_condition: "new_commits",
      cooldown_hours: 24,
      default_confidence_threshold: 80,
      priority: 5
    )
  end

  test "valid with all required fields" do
    assert @agent.valid?
  end

  test "invalid without name" do
    @agent.name = nil
    assert_not @agent.valid?
  end

  test "invalid without slug" do
    @agent.slug = nil
    assert_not @agent.valid?
  end

  test "invalid without system_prompt" do
    @agent.system_prompt = nil
    assert_not @agent.valid?
  end

  test "slug must be unique" do
    @agent.save!
    dup = @agent.dup
    assert_not dup.valid?
    assert_includes dup.errors[:slug], "has already been taken"
  end

  test "slug is normalized from spaces and uppercase" do
    @agent.slug = "Bad Slug"
    assert @agent.valid?
    assert_equal "bad-slug", @agent.slug
  end

  test "run_condition must be in allowed list" do
    @agent.run_condition = "never"
    assert_not @agent.valid?
  end

  test "confidence_threshold in range 0-100" do
    @agent.default_confidence_threshold = 101
    assert_not @agent.valid?
    @agent.default_confidence_threshold = -1
    assert_not @agent.valid?
    @agent.default_confidence_threshold = 50
    assert @agent.valid?
  end

  test "priority in range 1-10" do
    @agent.priority = 0
    assert_not @agent.valid?
    @agent.priority = 11
    assert_not @agent.valid?
    @agent.priority = 5
    assert @agent.valid?
  end

  test "scopes: builtin and custom" do
    @agent.save!
    builtin = FactoryAgent.create!(name: "Built-in", slug: "built-in", system_prompt: "test", builtin: true, run_condition: "daily")
    assert_includes FactoryAgent.builtin, builtin
    assert_includes FactoryAgent.custom, @agent
    assert_not_includes FactoryAgent.builtin, @agent
  end
end
