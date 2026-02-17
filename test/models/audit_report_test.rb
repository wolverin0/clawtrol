# frozen_string_literal: true

require "test_helper"

class AuditReportTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    report = AuditReport.new(user: users(:one), report_type: "weekly", overall_score: 7.5)
    assert report.valid?
  end

  test "validates report_type inclusion" do
    report = AuditReport.new(user: users(:one), report_type: "monthly", overall_score: 7.5)
    assert_not report.valid?
    assert report.errors[:report_type].any?
  end

  test "validates overall_score range" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 11)
    assert_not report.valid?
    assert report.errors[:overall_score].any?
  end

  test "daily scope returns only daily reports" do
    daily = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 6.0)
    weekly = AuditReport.create!(user: users(:one), report_type: "weekly", overall_score: 8.0)

    assert_includes AuditReport.daily, daily
    assert_not_includes AuditReport.daily, weekly
  end

  test "recent scope orders by created_at desc" do
    older = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 5.0)
    newer = AuditReport.create!(user: users(:one), report_type: "weekly", overall_score: 9.0)

    older.update_columns(created_at: 2.days.ago)
    newer.update_columns(created_at: 1.day.ago)

    assert_equal [newer.id, older.id], AuditReport.recent.where(id: [older.id, newer.id]).pluck(:id)
  end

  # --- Associations ---

  test "has_many behavioral_interventions" do
    report = AuditReport.create!(user: users(:one), report_type: "weekly", overall_score: 8.0)
    intervention = BehavioralIntervention.create!(
      user: users(:one),
      audit_report: report,
      rule: "test rule",
      category: "test",
      status: "active"
    )

    assert_includes report.behavioral_interventions, intervention
  end

  test "behavioral_interventions are destroyed with report" do
    report = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 5.0)
    intervention = BehavioralIntervention.create!(
      user: users(:one),
      audit_report: report,
      rule: "test rule",
      category: "test",
      status: "active"
    )
    intervention_id = intervention.id

    report.destroy!

    assert_nil BehavioralIntervention.find_by(id: intervention_id)
  end

  # --- Edge cases ---

  test "validates overall_score cannot be negative" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: -1)
    assert_not report.valid?
    assert_includes report.errors[:overall_score], "must be greater than or equal to 0"
  end

  test "validates overall_score can be zero" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 0)
    assert report.valid?
  end

  # --- More validation edge cases ---

  test "validates overall_score maximum is 10" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 10.1)
    assert_not report.valid?
    assert_includes report.errors[:overall_score], "must be less than or equal to 10"
  end

  test "validates overall_score at maximum boundary" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 10)
    assert report.valid?
  end

  test "validates messages_analyzed must be integer" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, messages_analyzed: 1.5)
    assert_not report.valid?
    assert report.errors[:messages_analyzed].any?
  end

  test "validates messages_analyzed cannot be negative" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, messages_analyzed: -1)
    assert_not report.valid?
    assert report.errors[:messages_analyzed].any?
  end

  test "allows nil messages_analyzed" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5)
    assert report.valid?
  end

  test "validates session_files_analyzed must be integer" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, session_files_analyzed: 2.5)
    assert_not report.valid?
    assert report.errors[:session_files_analyzed].any?
  end

  test "validates session_files_analyzed cannot be negative" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, session_files_analyzed: -1)
    assert_not report.valid?
    assert report.errors[:session_files_analyzed].any?
  end

  test "allows nil session_files_analyzed" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5)
    assert report.valid?
  end

  test "validates report_type presence" do
    report = AuditReport.new(user: users(:one), overall_score: 5)
    assert_not report.valid?
    assert report.errors[:report_type].any?
  end

  test "validates report_path length maximum" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, report_path: "a" * 501)
    assert_not report.valid?
    assert report.errors[:report_path].any?
  end

  test "allows nil report_path" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5)
    assert report.valid?
  end

  test "validates scores must be a hash" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, scores: "not a hash")
    assert_not report.valid?
    assert_includes report.errors[:scores], "must be a JSON object"
  end

  test "allows valid scores hash" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, scores: { "test" => 1.0 })
    assert report.valid?
  end

  test "validates anti_pattern_counts must be a hash" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, anti_pattern_counts: [1, 2, 3])
    assert_not report.valid?
    assert_includes report.errors[:anti_pattern_counts], "must be a JSON object"
  end

  test "allows valid anti_pattern_counts hash" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 5, anti_pattern_counts: { "pattern1" => 5 })
    assert report.valid?
  end

  # --- Scopes ---

  test "weekly scope returns only weekly reports" do
    daily = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 6.0)
    weekly = AuditReport.create!(user: users(:one), report_type: "weekly", overall_score: 8.0)

    assert_includes AuditReport.weekly, weekly
    assert_not_includes AuditReport.weekly, daily
  end

  # --- Associations edge cases ---

  test "has user association" do
    report = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 6.0)
    assert_not_nil report.user
    assert_equal users(:one), report.user
  end

  test "behavioral_interventions count is correct" do
    report = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 5.0)
    3.times do |i|
      BehavioralIntervention.create!(
        user: users(:one),
        audit_report: report,
        rule: "rule_#{i}",
        category: "test",
        status: "active"
      )
    end

    assert_equal 3, report.behavioral_interventions.count
  end
end
