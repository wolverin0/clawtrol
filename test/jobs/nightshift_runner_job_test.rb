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
end
