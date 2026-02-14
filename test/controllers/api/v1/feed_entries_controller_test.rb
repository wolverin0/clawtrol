# frozen_string_literal: true

require "test_helper"

class Api::V1::FeedEntriesControllerTest < ActionDispatch::IntegrationTest
  # --- Structural tests ---

  test "FeedEntriesController responds to index" do
    assert Api::V1::FeedEntriesController.method_defined?(:index)
  end

  test "FeedEntriesController responds to create" do
    assert Api::V1::FeedEntriesController.method_defined?(:create)
  end

  test "FeedEntriesController responds to stats" do
    assert Api::V1::FeedEntriesController.method_defined?(:stats)
  end

  test "FeedEntriesController responds to update" do
    assert Api::V1::FeedEntriesController.method_defined?(:update)
  end

  test "FeedEntriesController inherits from BaseController" do
    assert Api::V1::FeedEntriesController < Api::V1::BaseController
  end

  # --- Route tests ---

  test "routes to feed_entries#index" do
    assert_routing "/api/v1/feed_entries",
      controller: "api/v1/feed_entries", action: "index"
  end

  test "routes to feed_entries#create via POST" do
    assert_routing({ method: "post", path: "/api/v1/feed_entries" },
      controller: "api/v1/feed_entries", action: "create")
  end

  test "routes to feed_entries#stats" do
    assert_routing "/api/v1/feed_entries/stats",
      controller: "api/v1/feed_entries", action: "stats"
  end

  test "routes to feed_entries#update via PATCH" do
    assert_routing({ method: "patch", path: "/api/v1/feed_entries/1" },
      controller: "api/v1/feed_entries", action: "update", id: "1")
  end

  # --- Auth tests ---

  test "index requires authentication" do
    get "/api/v1/feed_entries"
    assert_response :unauthorized
  end

  test "create requires authentication" do
    post "/api/v1/feed_entries", params: { feed_name: "test", title: "test", url: "https://example.com" }
    assert_response :unauthorized
  end

  test "stats requires authentication" do
    get "/api/v1/feed_entries/stats"
    assert_response :unauthorized
  end
end
