# frozen_string_literal: true

require "test_helper"

class NightbeatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    sign_in_as(@user)
  end

  test "requires authentication" do
    sign_out
    get nightbeat_path
    assert_response :redirect
  end

  test "renders nightbeat page" do
    get nightbeat_path
    assert_response :success
  end

  test "shows nightly tasks completed overnight" do
    Task.create!(
      name: "Nightly task",
      user: @user,
      board: @board,
      status: :done,
      completed: true,
      completed_at: Time.zone.now.change(hour: 3),
      nightly: true
    )

    get nightbeat_path
    assert_response :success
    assert_match "Nightly task", response.body
  end

  test "does not show non-nightly tasks" do
    Task.create!(
      name: "Regular done task",
      user: @user,
      board: @board,
      status: :done,
      completed: true,
      completed_at: Time.zone.now.change(hour: 3),
      nightly: false
    )

    get nightbeat_path
    assert_response :success
    assert_no_match(/Regular done task/, response.body)
  end

  private


end
