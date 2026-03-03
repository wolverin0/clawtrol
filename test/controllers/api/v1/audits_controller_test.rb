# frozen_string_literal: true

require "test_helper"

class Api::V1::AuditsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "ingest creates an audit report and calls BehavioralInterventionUpdaterService" do
    assert_difference("AuditReport.count", 1) do
      post ingest_api_v1_audits_path, params: {
        report_type: "daily",
        overall_score: 8.5,
        scores: { "testing" => 4.0 }
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_includes json_response, "id"
    assert_includes json_response, "interventions_updated"
  end

  test "latest returns the most recent audit report" do
    report = @user.audit_reports.create!(
      report_type: "daily",
      overall_score: 9.0,
      scores: { "testing" => 5.0 }
    )

    get latest_api_v1_audits_path, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "9.0", json_response["overall_score"].to_s
    assert_equal "daily", json_response["report_type"]
  end
end
