# frozen_string_literal: true

require "test_helper"

class BehavioralInterventionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # Validation tests
  test "valid with required attributes" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: "focus", status: "active")
    assert intervention.valid?
  end

  test "requires rule" do
    intervention = BehavioralIntervention.new(user: @user, rule: nil, category: "focus", status: "active")
    assert_not intervention.valid?
    assert intervention.errors[:rule].any?
  end

  test "requires category" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: nil, status: "active")
    assert_not intervention.valid?
    assert intervention.errors[:category].any?
  end

  test "validates status inclusion" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: "focus", status: "pending")
    assert_not intervention.valid?
    assert intervention.errors[:status].any?
  end

  test "validates score range - baseline too high" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: "focus", status: "active", baseline_score: 11)
    assert_not intervention.valid?
    assert intervention.errors[:baseline_score].any?
  end

  test "validates score range - current too high" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: "focus", status: "active", current_score: 11)
    assert_not intervention.valid?
    assert intervention.errors[:current_score].any?
  end

  test "validates score range - negative baseline" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: "focus", status: "active", baseline_score: -1)
    assert_not intervention.valid?
    assert intervention.errors[:baseline_score].any?
  end

  test "allows nil scores" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Take pauses", category: "focus", status: "active")
    assert intervention.valid?
  end

  # Scope tests
  test "active scope returns only active interventions" do
    active = BehavioralIntervention.create!(user: @user, rule: "Do A", category: "focus", status: "active")
    resolved = BehavioralIntervention.create!(user: @user, rule: "Do B", category: "focus", status: "resolved")
    regressed = BehavioralIntervention.create!(user: @user, rule: "Do C", category: "focus", status: "regressed")

    assert_includes BehavioralIntervention.active, active
    assert_not_includes BehavioralIntervention.active, resolved
    assert_not_includes BehavioralIntervention.active, regressed
  end

  test "resolved scope returns only resolved interventions" do
    active = BehavioralIntervention.create!(user: @user, rule: "Do A", category: "focus", status: "active")
    resolved = BehavioralIntervention.create!(user: @user, rule: "Do B", category: "focus", status: "resolved")

    assert_includes BehavioralIntervention.resolved, resolved
    assert_not_includes BehavioralIntervention.resolved, active
  end

  test "regressed scope returns only regressed interventions" do
    active = BehavioralIntervention.create!(user: @user, rule: "Do A", category: "focus", status: "active")
    regressed = BehavioralIntervention.create!(user: @user, rule: "Do B", category: "focus", status: "regressed")

    assert_includes BehavioralIntervention.regressed, regressed
    assert_not_includes BehavioralIntervention.regressed, active
  end

  # Method tests
  test "resolve! updates status and resolved_at" do
    intervention = BehavioralIntervention.create!(user: @user, rule: "Do A", category: "focus", status: "active")

    intervention.resolve!
    intervention.reload

    assert_equal "resolved", intervention.status
    assert_not_nil intervention.resolved_at
  end

  test "regress! updates status and regressed_at" do
    intervention = BehavioralIntervention.create!(user: @user, rule: "Do A", category: "focus", status: "active")

    intervention.regress!
    intervention.reload

    assert_equal "regressed", intervention.status
    assert_not_nil intervention.regressed_at
  end

  # Association tests
  test "belongs_to user" do
    intervention = BehavioralIntervention.create!(user: @user, rule: "Test", category: "focus", status: "active")
    assert_equal @user, intervention.user
  end

  test "belongs_to audit_report (optional)" do
    intervention = BehavioralIntervention.create!(user: @user, rule: "Test", category: "focus", status: "active")
    assert_nil intervention.audit_report

    report = AuditReport.create!(user: @user, report_type: "security")
    intervention.update!(audit_report: report)
    assert_equal report, intervention.audit_report
  end

  # Status constants
  test "STATUSES contains expected values" do
    assert_equal %w[active resolved regressed], BehavioralIntervention::STATUSES
  end

  # Additional validation tests
  test "rule cannot exceed 1000 characters" do
    intervention = BehavioralIntervention.new(user: @user, rule: "a" * 1001, category: "focus", status: "active")
    assert_not intervention.valid?
    assert_includes intervention.errors[:rule].join, "too long"
  end

  test "category accepts valid values" do
    %w[focus breaks sleep exercise nutrition hydration].each do |cat|
      intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: cat, status: "active")
      assert intervention.valid?, "Category '#{cat}' should be valid"
    end
  end

  test "category cannot exceed 100 characters" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: "x" * 101, status: "active")
    assert_not intervention.valid?
  end

  test "allows nil category" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: nil, status: "active")
    assert_not intervention.valid?
  end

  test "baseline_score allows 0" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: "focus", status: "active", baseline_score: 0)
    assert intervention.valid?
  end

  test "baseline_score allows 10" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: "focus", status: "active", baseline_score: 10)
    assert intervention.valid?
  end

  test "baseline_score rejects 11" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: "focus", status: "active", baseline_score: 11)
    assert_not intervention.valid?
  end

  test "current_score allows 0" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: "focus", status: "active", current_score: 0)
    assert intervention.valid?
  end

  test "current_score allows 10" do
    intervention = BehavioralIntervention.new(user: @user, rule: "Test", category: "focus", status: "active", current_score: 10)
    assert intervention.valid?
  end

  # Callback/state tests
  test "resolve! sets resolved_at timestamp" do
    intervention = BehavioralIntervention.create!(user: @user, rule: "Test", category: "focus", status: "active", resolved_at: nil)
    assert_nil intervention.resolved_at

    intervention.resolve!
    intervention.reload

    assert_not_nil intervention.resolved_at
    assert_equal "resolved", intervention.status
  end

  test "regress! sets regressed_at timestamp" do
    intervention = BehavioralIntervention.create!(user: @user, rule: "Test", category: "focus", status: "active", regressed_at: nil)
    assert_nil intervention.regressed_at

    intervention.regress!
    intervention.reload

    assert_not_nil intervention.regressed_at
    assert_equal "regressed", intervention.status
  end

  test "strict_loading mode is configured" do
    intervention = BehavioralIntervention.new
    assert_includes [:n_plus_one, :all], intervention.class.strict_loading_mode
  end

  # Edge cases
  test "handles empty string as rule" do
    intervention = BehavioralIntervention.new(user: @user, rule: "", category: "focus", status: "active")
    assert_not intervention.valid?
  end

  test "handles whitespace-only rule" do
    intervention = BehavioralIntervention.new(user: @user, rule: "   ", category: "focus", status: "active")
    assert_not intervention.valid?
  end
end
