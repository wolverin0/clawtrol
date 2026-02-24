require "test_helper"

class MissionControlControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get mission_control_url
    assert_response :success
    assert_select "h1", "Mission Control Health Dashboard"
    assert_select ".card", minimum: 3
  end

  test "sets no-store cache header for sensitive dashboard data" do
    get mission_control_url

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "shows unknown migration state when database is disconnected" do
    fake_connection = Object.new
    fake_connection.define_singleton_method(:active?) { false }
    fake_connection.define_singleton_method(:migration_context) do
      raise "migration context should not be called when db is disconnected"
    end

    ActiveRecord::Base.stub(:connection, fake_connection) do
      get mission_control_url
    end

    assert_response :success
    assert_select "span", text: "Unknown"
  end

  test "caches health snapshot briefly to avoid repeated expensive checks" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    fake_snapshot = {
      ruby_version: "3.3.0",
      rails_version: "8.0.0",
      environment: "test",
      database_connected: true,
      pending_migrations: false,
      uptime: "up 1 minute",
      memory_usage: "100 MB"
    }

    call_count = 0
    MissionControlHealthSnapshotService.stub(:call, -> {
      call_count += 1
      fake_snapshot
    }) do
      get mission_control_url
      get mission_control_url
    end

    assert_equal 1, call_count
  ensure
    Rails.cache = original_cache
  end
end
