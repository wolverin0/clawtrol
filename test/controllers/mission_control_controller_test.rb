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

  test "sets strict no-cache headers for sensitive dashboard data" do
    get mission_control_url

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "0", response.headers["Expires"]
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

  test "recomputes cached snapshot after ttl expires" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    call_count = 0
    MissionControlHealthSnapshotService.stub(:call, -> {
      call_count += 1
      {
        ruby_version: "3.3.0",
        rails_version: "8.0.0",
        environment: "test",
        database_connected: true,
        pending_migrations: false,
        uptime: "up #{call_count} minute",
        memory_usage: "100 MB"
      }
    }) do
      get mission_control_url
      get mission_control_url

      travel 31.seconds do
        get mission_control_url
      end
    end

    assert_equal 2, call_count
  ensure
    Rails.cache = original_cache
  end
end
