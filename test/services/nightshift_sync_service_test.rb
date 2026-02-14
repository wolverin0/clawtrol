# frozen_string_literal: true

require "test_helper"

class NightshiftSyncServiceTest < ActiveSupport::TestCase
  def setup
    @service = NightshiftSyncService.new
  end

  # --- sync_crons ---

  test "sync_crons returns hash with synced and selections_created" do
    # Stub the private method to avoid shelling out to openclaw CLI
    @service.stub(:fetch_nightshift_crons, []) do
      result = @service.sync_crons
      assert_kind_of Hash, result
      assert_includes result.keys, :synced
      assert_includes result.keys, :selections_created
      assert_equal 0, result[:synced]
      assert_equal 0, result[:selections_created]
    end
  end

  test "sync_crons skips crons with blank names" do
    crons = [{ "name" => "🌙 NS: ", "enabled" => true }]
    @service.stub(:fetch_nightshift_crons, crons) do
      result = @service.sync_crons
      assert_equal 0, result[:synced]
    end
  end

  test "sync_crons strips NS prefix from mission name" do
    crons = [
      { "name" => "🌙 NS: Security Audit", "enabled" => true, "payload" => { "timeoutSeconds" => 600 } }
    ]
    @service.stub(:fetch_nightshift_crons, crons) do
      result = @service.sync_crons
      assert_equal 1, result[:synced]
      mission = NightshiftMission.find_by(name: "Security Audit")
      assert_not_nil mission
      assert_equal "always", mission.frequency
      assert_equal "general", mission.category
      assert_equal "🌙", mission.icon
      assert_equal 10, mission.estimated_minutes # 600/60 = 10
    end
  end

  test "sync_crons does not recreate existing missions" do
    existing = NightshiftMission.create!(
      name: "Existing Mission",
      enabled: true,
      frequency: "always",
      category: "security"
    )

    crons = [
      { "name" => "🌙 NS: Existing Mission", "enabled" => true }
    ]
    @service.stub(:fetch_nightshift_crons, crons) do
      assert_no_difference("NightshiftMission.count") do
        result = @service.sync_crons
        assert_equal 1, result[:synced]
      end
    end
    # Should not overwrite category
    assert_equal "security", existing.reload.category
  end

  # --- sync_tonight_selections ---

  test "sync_tonight_selections returns count of created selections" do
    result = @service.sync_tonight_selections
    assert_kind_of Integer, result
    assert result >= 0
  end

  test "sync_tonight_selections creates selection for due missions" do
    mission = NightshiftMission.create!(
      name: "Test Tonight #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general"
    )

    # "always" frequency + due_tonight? should be true
    if mission.due_tonight?
      assert_difference("NightshiftSelection.count") do
        @service.sync_tonight_selections
      end

      selection = NightshiftSelection.for_tonight.find_by(nightshift_mission_id: mission.id)
      assert_not_nil selection
      assert_equal mission.name, selection.title
      assert_equal "pending", selection.status
      assert selection.enabled?
    end
  end

  test "sync_tonight_selections does not duplicate existing selections" do
    mission = NightshiftMission.create!(
      name: "No Dup #{SecureRandom.hex(4)}",
      enabled: true,
      frequency: "always",
      category: "general"
    )

    NightshiftSelection.create!(
      nightshift_mission_id: mission.id,
      title: mission.name,
      scheduled_date: Date.current,
      enabled: true,
      status: "pending"
    )

    assert_no_difference("NightshiftSelection.count") do
      @service.sync_tonight_selections
    end
  end

  test "sync_tonight_selections ignores disabled missions" do
    mission = NightshiftMission.create!(
      name: "Disabled #{SecureRandom.hex(4)}",
      enabled: false,
      frequency: "always",
      category: "general"
    )

    @service.sync_tonight_selections
    assert_nil NightshiftSelection.for_tonight.find_by(nightshift_mission_id: mission.id)
  end

  # --- fetch_nightshift_crons (private, structural) ---

  test "service responds to sync_crons" do
    assert_respond_to @service, :sync_crons
  end

  test "service responds to sync_tonight_selections" do
    assert_respond_to @service, :sync_tonight_selections
  end
end
