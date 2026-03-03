# frozen_string_literal: true

require "test_helper"

module Zeroclaw
  class AuditorSweepServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
      @user = users(:one)
      @board = boards(:one)
    end

    teardown { clear_enqueued_jobs }

    test "enqueues only auditable in_review tasks" do
      Task.create!(
        user: @user,
        board: @board,
        name: "Auditable in review",
        status: :in_review,
        assigned_to_agent: true,
        tags: ["coding"],
        description: "## Agent Output\nLine one\nLine two"
      )

      Task.create!(
        user: @user,
        board: @board,
        name: "Not auditable",
        status: :in_review,
        assigned_to_agent: true,
        tags: ["misc"],
        description: "## Agent Output\nLine one\nLine two"
      )

      result = nil
      assert_enqueued_jobs 1, only: ZeroclawAuditorJob do
        result = Zeroclaw::AuditorSweepService.new(limit: 10, lookback_hours: 24, min_interval_seconds: 300).call
      end

      assert_equal 1, result[:enqueued]
      assert_equal 1, result[:skipped_not_auditable]
      assert_equal "cron_sweep", result[:trigger]
    end

    test "skips recently audited tasks when not forced" do
      Task.create!(
        user: @user,
        board: @board,
        name: "Recent audited",
        status: :in_review,
        assigned_to_agent: true,
        tags: ["report"],
        description: "## Agent Output\nLine one\nLine two",
        state_data: { "auditor" => { "last" => { "completed_at" => 2.minutes.ago.iso8601 } } }
      )

      result = nil
      assert_no_enqueued_jobs only: ZeroclawAuditorJob do
        result = Zeroclaw::AuditorSweepService.new(limit: 10, min_interval_seconds: 600, lookback_hours: 24, force: false).call
      end

      assert_equal 0, result[:enqueued]
      assert_equal 1, result[:skipped_recent]
      assert_equal false, result[:force]
    end
  end
end
