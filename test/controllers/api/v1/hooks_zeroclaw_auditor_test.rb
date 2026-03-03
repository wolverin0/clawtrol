# frozen_string_literal: true

require "test_helper"

class Api::V1::HooksZeroclawAuditorTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    @task = tasks(:one)
    @token = Rails.application.config.hooks_token
  end

  teardown { clear_enqueued_jobs }

  test "rejects webhook trigger with invalid token" do
    post "/api/v1/hooks/zeroclaw_auditor",
         params: { task_id: @task.id },
         headers: { "X-Hook-Token" => "wrong" },
         as: :json

    assert_response :unauthorized
  end

  test "enqueues auditor job from webhook for eligible task" do
    @task.update!(
      status: :in_review,
      assigned_to_agent: true,
      tags: ["report"],
      description: "## Agent Output\nSummary line one\nSummary line two"
    )

    assert_enqueued_jobs 1, only: ZeroclawAuditorJob do
      post "/api/v1/hooks/zeroclaw_auditor",
           params: { task_id: @task.id },
           headers: { "X-Hook-Token" => @token },
           as: :json
    end

    assert_response :success
    assert_equal true, response.parsed_body["queued"]
  end
end
