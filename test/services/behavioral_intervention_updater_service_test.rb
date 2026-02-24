# frozen_string_literal: true

require "test_helper"

class BehavioralInterventionUpdaterServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @report = @user.audit_reports.create!(
      report_type: "daily",
      overall_score: 5.0,
      scores: { "security" => 5.0 }
    )
  end

  test "returns 0 if scores is not a hash" do
    @report.update!(scores: nil)
    assert_equal 0, BehavioralInterventionUpdaterService.call(user: @user, report: @report)
  end

  test "creates new intervention if score is below 5.0" do
    @report.update!(scores: { "security" => 4.5 })
    
    assert_difference("BehavioralIntervention.count", 1) do
      updated_count = BehavioralInterventionUpdaterService.call(user: @user, report: @report)
      assert_equal 1, updated_count
    end

    intervention = BehavioralIntervention.last
    assert_equal "security", intervention.category
    assert_equal 4.5, intervention.current_score
    assert_equal 4.5, intervention.baseline_score
    assert_equal "active", intervention.status
  end

  test "updates existing intervention" do
    intervention = @user.behavioral_interventions.create!(
      category: "testing",
      rule: "needs tests",
      baseline_score: 4.0,
      current_score: 4.0,
      status: "active"
    )

    @report.update!(scores: { "testing" => 4.5 })

    updated_count = BehavioralInterventionUpdaterService.call(user: @user, report: @report)
    assert_equal 1, updated_count

    intervention.reload
    assert_equal 4.5, intervention.current_score
    assert_equal "active", intervention.status
  end

  test "resolves intervention if improved by 1.0 twice" do
    intervention = @user.behavioral_interventions.create!(
      category: "testing",
      rule: "needs tests",
      baseline_score: 4.0,
      current_score: 4.0,
      status: "active"
    )

    previous_report = @user.audit_reports.create!(
      report_type: "daily",
      overall_score: 5.0,
      scores: { "testing" => 5.0 }
    )

    @report.update!(scores: { "testing" => 5.0 })

    BehavioralInterventionUpdaterService.call(user: @user, report: @report)

    intervention.reload
    assert_equal "resolved", intervention.status
  end

  test "regresses intervention if dropped by 1.0" do
    intervention = @user.behavioral_interventions.create!(
      category: "testing",
      rule: "needs tests",
      baseline_score: 4.0,
      current_score: 4.0,
      status: "active"
    )

    @report.update!(scores: { "testing" => 3.0 })

    BehavioralInterventionUpdaterService.call(user: @user, report: @report)

    intervention.reload
    assert_equal "regressed", intervention.status
  end
end
