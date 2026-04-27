# frozen_string_literal: true

require "test_helper"

class DeliveryTargetResolverTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:default)
  end

  test "prefers session target when origin_session_key exists" do
    @task.update_columns(
      origin_session_key: "agent:main:abc",
      origin_session_id: "sid-1",
      origin_chat_id: "12345",
      origin_thread_id: 9
    )

    resolution = DeliveryTargetResolver.resolve(@task)
    assert_equal :session, resolution.channel
    assert_equal "agent:main:abc", resolution.session_key
    assert_nil resolution.chat_id
    assert_equal "origin_session_key_present", resolution.reason
  end

  test "uses telegram target when only chat origin is present" do
    @task.update_columns(
      origin_session_key: nil,
      origin_session_id: nil,
      origin_chat_id: "12345",
      origin_thread_id: 7
    )

    resolution = DeliveryTargetResolver.resolve(@task)
    assert_equal :telegram, resolution.channel
    assert_equal "12345", resolution.chat_id
    assert_equal 7, resolution.thread_id
    assert_equal "origin_chat_id_present", resolution.reason
  end

  test "returns none when origin fields are missing" do
    @task.update_columns(
      origin_session_key: nil,
      origin_session_id: nil,
      origin_chat_id: nil,
      origin_thread_id: nil
    )

    resolution = DeliveryTargetResolver.resolve(@task)
    assert_equal :none, resolution.channel
    assert_equal "missing_origin_delivery_fields", resolution.reason
  end
end
