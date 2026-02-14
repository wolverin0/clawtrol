# frozen_string_literal: true

require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  # --- Authentication ---

  test "index requires authentication" do
    get feeds_path
    assert_response :redirect
  end

  # --- Structural tests for controller actions ---

  test "FeedsController responds to index" do
    assert FeedsController.method_defined?(:index)
  end

  test "FeedsController responds to show" do
    assert FeedsController.method_defined?(:show)
  end

  test "FeedsController responds to update" do
    assert FeedsController.method_defined?(:update)
  end

  test "FeedsController responds to mark_read" do
    assert FeedsController.method_defined?(:mark_read)
  end

  test "FeedsController responds to dismiss" do
    assert FeedsController.method_defined?(:dismiss)
  end

  test "FeedsController responds to destroy" do
    assert FeedsController.method_defined?(:destroy)
  end

  test "FeedsController inherits from ApplicationController" do
    assert FeedsController < ApplicationController
  end

  # --- Route tests ---

  test "routes to feeds#index" do
    assert_routing "/feeds", controller: "feeds", action: "index"
  end

  test "routes to feeds#show" do
    assert_routing "/feeds/1", controller: "feeds", action: "show", id: "1"
  end

  test "routes to feeds#update via PATCH" do
    assert_routing({ method: "patch", path: "/feeds/1" }, controller: "feeds", action: "update", id: "1")
  end

  test "routes to feeds#mark_read via POST" do
    assert_routing({ method: "post", path: "/feeds/mark_read" }, controller: "feeds", action: "mark_read")
  end

  test "routes to feeds#dismiss via POST" do
    assert_routing({ method: "post", path: "/feeds/1/dismiss" }, controller: "feeds", action: "dismiss", id: "1")
  end
end
