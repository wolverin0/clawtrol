# frozen_string_literal: true

require "test_helper"

class BehavioralInterventionTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    intervention = BehavioralIntervention.new(user: users(:one), rule: "Take pauses", category: "focus", status: "active")
    assert intervention.valid?
  end

  test "requires rule" do
    intervention = BehavioralIntervention.new(user: users(:one), rule: nil, category: "focus", status: "active")
    assert_not intervention.valid?
    assert intervention.errors[:rule].any?
  end

  test "validates status inclusion" do
    intervention = BehavioralIntervention.new(user: users(:one), rule: "Take pauses", category: "focus", status: "pending")
    assert_not intervention.valid?
    assert intervention.errors[:status].any?
  end

  test "validates score range" do
    intervention = BehavioralIntervention.new(user: users(:one), rule: "Take pauses", category: "focus", status: "active", baseline_score: 11)
    assert_not intervention.valid?
    assert intervention.errors[:baseline_score].any?
  end

  test "active scope returns only active interventions" do
    active = BehavioralIntervention.create!(user: users(:one), rule: "Do A", category: "focus", status: "active")
    resolved = BehavioralIntervention.create!(user: users(:one), rule: "Do B", category: "focus", status: "resolved")

    assert_includes BehavioralIntervention.active, active
    assert_not_includes BehavioralIntervention.active, resolved
  end

  test "resolve! updates status and resolved_at" do
    intervention = BehavioralIntervention.create!(user: users(:one), rule: "Do A", category: "focus", status: "active")

    intervention.resolve!
    intervention.reload

    assert_equal "resolved", intervention.status
    assert_not_nil intervention.resolved_at
  end
end
