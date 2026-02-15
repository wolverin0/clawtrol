# frozen_string_literal: true

require "test_helper"

class FactoryEngineServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @loop = FactoryLoop.create!(
      user: @user,
      name: "Test Loop",
      slug: "test-loop-#{SecureRandom.hex(4)}",
      interval_ms: 300_000,
      status: "playing",
      total_cycles: 0,
      total_errors: 0,
      consecutive_failures: 0,
      model: "minimax"
    )
    @cycle = FactoryCycleLog.create!(
      factory_loop: @loop,
      cycle_number: 1,
      status: "running",
      started_at: 1.minute.ago
    )
    @service = FactoryEngineService.new(@user)
  end

  # --- record_cycle_result: successful ---

  test "record_cycle_result marks cycle completed" do
    @service.record_cycle_result(@cycle, status: "completed", summary: "All good")

    @cycle.reload
    assert_equal "completed", @cycle.status
    assert_equal "All good", @cycle.summary
    assert_not_nil @cycle.finished_at
    assert @cycle.duration_ms > 0
  end

  test "record_cycle_result increments total_cycles on success" do
    assert_equal 0, @loop.total_cycles
    @service.record_cycle_result(@cycle, status: "completed")
    @loop.reload
    assert_equal 1, @loop.total_cycles
  end

  test "record_cycle_result resets consecutive_failures on success" do
    @loop.update!(consecutive_failures: 3)
    @service.record_cycle_result(@cycle, status: "completed")
    @loop.reload
    assert_equal 0, @loop.consecutive_failures
  end

  test "record_cycle_result sets last_cycle_at on success" do
    @service.record_cycle_result(@cycle, status: "completed")
    @loop.reload
    assert_not_nil @loop.last_cycle_at
    assert_in_delta Time.current, @loop.last_cycle_at, 2.seconds
  end

  test "record_cycle_result clears error fields on success" do
    @loop.update!(last_error_at: 1.hour.ago, last_error_message: "old error")
    @service.record_cycle_result(@cycle, status: "completed")
    @loop.reload
    assert_nil @loop.last_error_at
    assert_nil @loop.last_error_message
  end

  # --- record_cycle_result: failed ---

  test "record_cycle_result increments consecutive_failures on failure" do
    @service.record_cycle_result(@cycle, status: "failed", summary: "Something broke")
    @loop.reload
    assert_equal 1, @loop.consecutive_failures
    assert_equal 1, @loop.total_errors
  end

  test "record_cycle_result sets error fields on failure" do
    @service.record_cycle_result(@cycle, status: "failed", summary: "Crash!")
    @loop.reload
    assert_not_nil @loop.last_error_at
    assert_equal "Crash!", @loop.last_error_message
  end

  test "record_cycle_result error_pauses loop after MAX_CONSECUTIVE_FAILURES" do
    @loop.update!(consecutive_failures: FactoryEngineService::MAX_CONSECUTIVE_FAILURES - 1)
    @service.record_cycle_result(@cycle, status: "failed", summary: "Final straw")
    @loop.reload
    assert_equal "error_paused", @loop.status
    assert_equal FactoryEngineService::MAX_CONSECUTIVE_FAILURES, @loop.consecutive_failures
  end

  test "record_cycle_result does NOT error_pause before threshold" do
    @loop.update!(consecutive_failures: FactoryEngineService::MAX_CONSECUTIVE_FAILURES - 2)
    @service.record_cycle_result(@cycle, status: "failed", summary: "Not yet")
    @loop.reload
    assert_equal "playing", @loop.status
  end

  # --- record_cycle_result: token tracking ---

  test "record_cycle_result stores token counts" do
    @service.record_cycle_result(
      @cycle,
      status: "completed",
      input_tokens: 1500,
      output_tokens: 3000,
      model_used: "minimax"
    )
    @cycle.reload
    assert_equal 1500, @cycle.input_tokens
    assert_equal 3000, @cycle.output_tokens
    assert_equal "minimax", @cycle.model_used
  end

  # --- duration_ms ---

  test "record_cycle_result calculates duration_ms from started_at" do
    @cycle.update!(started_at: 5.seconds.ago)
    @service.record_cycle_result(@cycle, status: "completed")
    @cycle.reload
    assert @cycle.duration_ms >= 4000
    assert @cycle.duration_ms < 10000
  end

  # started_at has a NOT NULL constraint in the DB, so nil case can't occur in practice
end
