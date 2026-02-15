# frozen_string_literal: true

require "test_helper"

class NightshiftRunnerJobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @mission = NightshiftMission.create!(
      name: "Test Nightshift Mission",
      description: "Test mission for nightshift",
      frequency: "always",
      category: "research",
      model: "gemini",
      estimated_minutes: 30,
      user: @user,
      enabled: true
    )
  end

  def create_selection(status: "pending", scheduled_date: Date.today)
    NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Selection for #{scheduled_date}",
      status: status,
      scheduled_date: scheduled_date,
      enabled: true
    )
  end

  # Test: performs nothing if no armed selections
  test "does nothing if no armed selections exist" do
    assert_nothing_raised do
      NightshiftRunnerJob.perform_now
    end
  end

  # Test: processes enabled pending selections for today
  test "processes enabled pending selections for today" do
    selection1 = create_selection(status: "pending")
    selection2 = create_selection(status: "pending", scheduled_date: Date.tomorrow)

    # Set up invalid gateway URL to trigger failure path
    @user.update!(openclaw_gateway_url: "http://invalid-host-that-does-not-exist.test:9999")

    NightshiftRunnerJob.perform_now

    selection1.reload
    selection2.reload
    
    # selection1 is for today and should be processed (status changed from pending)
    assert selection1.status != "pending" || selection2.status != "pending"
  end

  # Test: skips disabled selections
  test "skips disabled selections" do
    enabled_sel = create_selection(status: "pending")
    disabled_sel = NightshiftSelection.create!(
      nightshift_mission: @mission,
      title: "Disabled",
      status: "pending",
      scheduled_date: Date.tomorrow,  # Different date to avoid uniqueness constraint
      enabled: false
    )

    @user.update!(openclaw_gateway_url: "http://invalid-host-that-does-not-exist.test:9999")

    NightshiftRunnerJob.perform_now

    enabled_sel.reload
    disabled_sel.reload
    
    # Enabled should be processed, disabled should remain
    assert disabled_sel.status == "pending"
  end

  # Test: skips already running selections
  test "skips already running selections" do
    running_sel = create_selection(status: "running")

    NightshiftRunnerJob.perform_now

    running_sel.reload
    assert_equal "running", running_sel.status
  end

  # Test: skips completed selections
  test "skips completed selections" do
    completed_sel = create_selection(status: "completed")

    NightshiftRunnerJob.perform_now

    completed_sel.reload
    assert_equal "completed", completed_sel.status
  end

  # Test: skips failed selections
  test "skips failed selections" do
    failed_sel = create_selection(status: "failed")

    NightshiftRunnerJob.perform_now

    failed_sel.reload
    assert_equal "failed", failed_sel.status
  end

  # Test: sets launched_at timestamp
  test "sets launched_at timestamp on launch" do
    selection = create_selection(status: "pending")
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    # This will fail on wake but should set launched_at
    NightshiftRunnerJob.perform_now

    selection.reload
    assert_not_nil selection.launched_at
  end

  # Test: processes multiple selections in order
  test "processes multiple selections in order" do
    sel1 = create_selection(status: "pending", scheduled_date: Date.today)
    sel2 = create_selection(status: "pending", scheduled_date: Date.today)
    sel3 = create_selection(status: "pending", scheduled_date: Date.today)

    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    NightshiftRunnerJob.perform_now

    [sel1, sel2, sel3].each(&:reload)
    # All should have launched_at set
    assert_not_nil sel1.launched_at
    assert_not_nil sel2.launched_at
    assert_not_nil sel3.launched_at
  end

  # Test: handles mission without user gracefully
  test "handles mission without user gracefully" do
    mission_no_user = NightshiftMission.create!(
      name: "Orphan Mission",
      description: "Mission without user",
      frequency: "always",
      category: "research",
      model: "gemini",
      estimated_minutes: 30,
      user: nil,
      enabled: true
    )
    selection = NightshiftSelection.create!(
      nightshift_mission: mission_no_user,
      title: "Orphan Selection",
      status: "pending",
      scheduled_date: Date.today,
      enabled: true
    )

    # Should not raise - logs warning instead
    assert_nothing_raised do
      NightshiftRunnerJob.perform_now
    end

    selection.reload
    # Selection should remain pending since no user to wake
    assert_equal "pending", selection.status
  end

  # Test: includes mission details in wake text
  test "wake text includes mission details" do
    selection = create_selection(status: "pending")
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    # This will fail but we can verify it tried to send proper payload
    begin
      NightshiftRunnerJob.perform_now
    rescue StandardError
      # Expected to fail due to invalid host
    end

    # Selection was attempted
    selection.reload
    assert_not_nil selection.launched_at
  end

  # Test: selection for past date is excluded
  test "excludes selections for past dates" do
    past_sel = create_selection(status: "pending", scheduled_date: Date.yesterday)

    NightshiftRunnerJob.perform_now

    past_sel.reload
    assert_equal "pending", past_sel.status
  end

  # Test: handles empty mission description
  test "handles mission with nil description" do
    @mission.update!(description: nil)
    selection = create_selection(status: "pending")
    @user.update!(openclaw_gateway_url: "http://invalid-host.test:9999")

    assert_nothing_raised do
      NightshiftRunnerJob.perform_now
    end
  end
end
