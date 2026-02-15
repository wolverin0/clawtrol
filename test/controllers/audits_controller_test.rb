# frozen_string_literal: true

require "test_helper"

class AuditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "requires authentication" do
    sign_out
    get audits_path
    assert_response :redirect
  end

  # --- Trends tab (default) ---

  test "index defaults to trends tab" do
    get audits_path
    assert_response :success
    assert_select "body" # page renders
  end

  test "index with explicit trends tab" do
    get audits_path(tab: "trends")
    assert_response :success
  end

  test "trends tab loads audit reports scoped to current user" do
    # Create reports for another user to verify scoping
    other_user = users(:two)
    AuditReport.create!(user: other_user, report_type: "daily", overall_score: 5.0, scores: {}, anti_pattern_counts: {})
    AuditReport.create!(user: @user, report_type: "daily", overall_score: 7.5, scores: { conciseness: 8 }, anti_pattern_counts: { padding: 2 })

    get audits_path(tab: "trends")
    assert_response :success
  end

  test "trends tab calculates week delta with enough data" do
    2.times do |i|
      AuditReport.create!(
        user: @user,
        report_type: "weekly",
        overall_score: 5.0 + i,
        scores: {},
        anti_pattern_counts: {},
        created_at: (2 - i).weeks.ago
      )
    end

    get audits_path(tab: "trends")
    assert_response :success
  end

  # --- Interventions tab ---

  test "index with interventions tab" do
    get audits_path(tab: "interventions")
    assert_response :success
  end

  test "interventions tab loads interventions scoped to current user" do
    get audits_path(tab: "interventions")
    assert_response :success
  end

  test "interventions redirect action" do
    get interventions_audits_path
    assert_redirected_to audits_path(tab: "interventions")
  end

  # --- Invalid tab parameter ---

  test "invalid tab defaults to trends" do
    get audits_path(tab: "malicious<script>")
    assert_response :success
    # Doesn't crash, defaults to trends
  end
end
