# frozen_string_literal: true

require "test_helper"

class ClawRouterServiceTest < ActiveSupport::TestCase
  def build_task(**attrs)
    Task.create!(
      {
        name: "Test Task",
        user: users(:one),
        board: boards(:one),
        status: :inbox,
        priority: :none
      }.merge(attrs)
    )
  end

  test "planning tag routes to codex" do
    task = build_task(tags: ["planning"], model: nil)
    service = Pipeline::ClawRouterService.new(task)

    # Even if tiers would resolve to something else, planning must override.
    service.define_singleton_method(:resolve_model_from_tier) { |_tier| "glm" }

    assert_equal "codex", service.send(:select_model, { model_tier: "free" })
  end

  test "[Planning] name prefix routes to codex" do
    task = build_task(name: "[Planning] Build an execution plan", tags: [], model: nil)
    service = Pipeline::ClawRouterService.new(task)

    service.define_singleton_method(:resolve_model_from_tier) { |_tier| "glm" }

    assert_equal "codex", service.send(:select_model, { model_tier: "free" })
  end

  test "explicit task.model is respected even if planning" do
    task = build_task(name: "[Planning] Something", tags: ["planning"], model: "gemini")
    service = Pipeline::ClawRouterService.new(task)

    service.define_singleton_method(:resolve_model_from_tier) { |_tier| "glm" }

    assert_equal "gemini", service.send(:select_model, { model_tier: "free" })
  end

  test "non-planning task without model uses tier selection" do
    task = build_task(name: "Regular task", tags: ["bug"], model: nil)
    service = Pipeline::ClawRouterService.new(task)

    called_tier = nil
    service.define_singleton_method(:resolve_model_from_tier) do |tier|
      called_tier = tier
      "glm"
    end

    assert_equal "glm", service.send(:select_model, {})
    assert_equal "free", called_tier
  end
end
