# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class DashboardDataServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @gateway_client = Minitest::Mock.new
    # Gateway calls may or may not be hit depending on cache; stub safely
    @gateway_client.expect(:usage_cost, { "total" => "1.23" })
    @gateway_client.expect(:health, { "status" => "ok" })
  end

  test "returns a Result struct with all expected fields" do
    result = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    assert_kind_of DashboardDataService::Result, result
    assert_respond_to result, :inbox_count
    assert_respond_to result, :active_count
    assert_respond_to result, :review_count
    assert_respond_to result, :error_count
    assert_respond_to result, :done_today
    assert_respond_to result, :spawned_today
    assert_respond_to result, :failed_today
    assert_respond_to result, :active_tasks
    assert_respond_to result, :recent_tasks
    assert_respond_to result, :model_limits
    assert_respond_to result, :boards
    assert_respond_to result, :gateway_cost
    assert_respond_to result, :cost_analytics
    assert_respond_to result, :gateway_health
    assert_respond_to result, :saved_links_pending
    assert_respond_to result, :saved_links_recent
    assert_respond_to result, :feed_unread_count
    assert_respond_to result, :feed_high_relevance_count
    assert_respond_to result, :feed_recent
  end

  test "counts are non-negative integers" do
    result = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    assert_kind_of Integer, result.inbox_count
    assert_kind_of Integer, result.active_count
    assert_kind_of Integer, result.review_count
    assert_kind_of Integer, result.error_count
    assert result.inbox_count >= 0
    assert result.active_count >= 0
    assert result.review_count >= 0
    assert result.error_count >= 0
  end

  test "today stats are non-negative integers" do
    result = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    assert_kind_of Integer, result.done_today
    assert_kind_of Integer, result.spawned_today
    assert_kind_of Integer, result.failed_today
    assert result.done_today >= 0
    assert result.spawned_today >= 0
    assert result.failed_today >= 0
  end

  test "active_tasks limited to 10" do
    result = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    assert result.active_tasks.size <= 10
  end

  test "recent_tasks limited to 10" do
    result = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    assert result.recent_tasks.size <= 10
  end

  test "recent_tasks excludes archived" do
    result = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    result.recent_tasks.each do |task|
      assert_not_equal "archived", task.status
    end
  end

  test "gateway failure returns nil gracefully" do
    failing_client = Object.new
    def failing_client.usage_cost; raise StandardError, "timeout"; end
    def failing_client.health; raise StandardError, "timeout"; end

    # Clear cache to force fresh calls
    Rails.cache.delete("dashboard/cost/#{@user.id}")
    Rails.cache.delete("dashboard/health/#{@user.id}")
    Rails.cache.delete("dashboard/cost_analytics/#{@user.id}")

    result = DashboardDataService.call(user: @user, gateway_client: failing_client)

    assert_nil result.gateway_cost
    assert_nil result.gateway_health
    # cost_analytics doesn't use gateway_client, may or may not be nil
  end

  test "class method .call is a shortcut for new.call" do
    result1 = DashboardDataService.call(user: @user, gateway_client: @gateway_client)

    # Reset mocks
    client2 = Minitest::Mock.new
    client2.expect(:usage_cost, { "total" => "1.23" })
    client2.expect(:health, { "status" => "ok" })

    Rails.cache.clear
    result2 = DashboardDataService.new(user: @user, gateway_client: client2).call

    assert_kind_of DashboardDataService::Result, result1
    assert_kind_of DashboardDataService::Result, result2
  end
end
