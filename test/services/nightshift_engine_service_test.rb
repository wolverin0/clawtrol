# frozen_string_literal: true

require "test_helper"

class NightshiftEngineServiceTest < ActiveSupport::TestCase
  setup do
    @service = NightshiftEngineService.new
  end

  # --- Constants ---

  test "has a timeout of 30 minutes" do
    assert_equal 30, NightshiftEngineService::TIMEOUT_MINUTES
  end

  # --- complete_selection ---

  test "complete_selection sets running status and launched_at" do
    mission = NightshiftMission.create!(
      name: "Test Mission #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general",
      icon: "🌙"
    )
    selection = NightshiftSelection.create!(
      nightshift_mission: mission,
      title: mission.name,
      scheduled_date: Date.current,
      enabled: true,
      status: "pending"
    )

    result = @service.complete_selection(selection, status: :running)

    assert_equal "running", result.status
    assert_not_nil result.launched_at
  end

  test "complete_selection sets completed status and completed_at" do
    mission = NightshiftMission.create!(
      name: "Test Mission #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general",
      icon: "🌙"
    )
    selection = NightshiftSelection.create!(
      nightshift_mission: mission,
      title: mission.name,
      scheduled_date: Date.current,
      enabled: true,
      status: "running",
      launched_at: 10.minutes.ago
    )

    result = @service.complete_selection(selection, status: :completed, result: { summary: "All done" })

    assert_equal "completed", result.status
    assert_not_nil result.completed_at
    assert_equal({ "summary" => "All done" }, JSON.parse(result.result))
  end

  test "complete_selection updates mission last_run_at on completion" do
    mission = NightshiftMission.create!(
      name: "Test Mission #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general",
      icon: "🌙",
      last_run_at: 1.week.ago
    )
    selection = NightshiftSelection.create!(
      nightshift_mission: mission,
      title: mission.name,
      scheduled_date: Date.current,
      enabled: true,
      status: "running",
      launched_at: 10.minutes.ago
    )

    @service.complete_selection(selection, status: :completed)

    mission.reload
    assert mission.last_run_at > 1.minute.ago, "expected last_run_at to be updated to now"
  end

  test "complete_selection updates mission last_run_at on failure" do
    mission = NightshiftMission.create!(
      name: "Test Mission #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general",
      icon: "🌙"
    )
    selection = NightshiftSelection.create!(
      nightshift_mission: mission,
      title: mission.name,
      scheduled_date: Date.current,
      enabled: true,
      status: "running",
      launched_at: 10.minutes.ago
    )

    @service.complete_selection(selection, status: :failed)

    assert_equal "failed", selection.reload.status
    assert_not_nil selection.completed_at
    assert_not_nil mission.reload.last_run_at
  end

  test "complete_selection does not set launched_at again when completing" do
    mission = NightshiftMission.create!(
      name: "Test Mission #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general",
      icon: "🌙"
    )
    original_launch = 15.minutes.ago
    selection = NightshiftSelection.create!(
      nightshift_mission: mission,
      title: mission.name,
      scheduled_date: Date.current,
      enabled: true,
      status: "running",
      launched_at: original_launch
    )

    @service.complete_selection(selection, status: :completed)

    # launched_at should NOT be changed when completing
    assert_in_delta original_launch.to_f, selection.reload.launched_at.to_f, 1.0
  end
end
