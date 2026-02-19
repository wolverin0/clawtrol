# frozen_string_literal: true

require "test_helper"

class OriginRoutingServiceTest < ActiveSupport::TestCase
  test "applies origin fields from params" do
    task = Task.new(user: users(:one), board: boards(:one), name: "Origin task")
    params = ActionController::Parameters.new(task: {
      origin_chat_id: "123",
      origin_thread_id: "7",
      origin_session_key: "sess-key",
      origin_session_id: "sess-id"
    })

    OriginRoutingService.apply!(task, params: params, headers: {})

    assert_equal "123", task.origin_chat_id
    assert_equal 7, task.origin_thread_id
    assert_equal "sess-key", task.origin_session_key
    assert_equal "sess-id", task.origin_session_id
  end

  test "falls back to headers when params missing" do
    task = Task.new(user: users(:one), board: boards(:one), name: "Origin header task")
    headers = {
      "X-Origin-Chat-Id" => "456",
      "X-Origin-Thread-Id" => "9",
      "X-Origin-Session-Key" => "header-key"
    }

    OriginRoutingService.apply!(task, params: ActionController::Parameters.new, headers: headers)

    assert_equal "456", task.origin_chat_id
    assert_equal 9, task.origin_thread_id
    assert_equal "header-key", task.origin_session_key
  end
end
