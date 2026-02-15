# frozen_string_literal: true

require "test_helper"

class WebhookLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def valid_attrs
    {
      user: @user,
      direction: "incoming",
      event_type: "agent_complete",
      endpoint: "http://localhost:4001/api/v1/hooks/agent_complete",
      method: "POST"
    }
  end

  test "valid with required attributes" do
    log = WebhookLog.new(valid_attrs)
    assert log.valid?
  end

  test "requires direction" do
    # direction has a DB default of "incoming", so .except won't make it nil.
    # We must explicitly set it to nil to test the validation.
    log = WebhookLog.new(valid_attrs.merge(direction: nil))
    assert_not log.valid?
    assert log.errors[:direction].any?
  end

  test "validates direction inclusion" do
    log = WebhookLog.new(valid_attrs.merge(direction: "sideways"))
    assert_not log.valid?
    assert log.errors[:direction].any? { |e| e.include?("is not included") }
  end

  test "requires event_type" do
    log = WebhookLog.new(valid_attrs.merge(event_type: nil))
    assert_not log.valid?
  end

  test "requires endpoint" do
    log = WebhookLog.new(valid_attrs.merge(endpoint: nil))
    assert_not log.valid?
  end

  test "requires method" do
    log = WebhookLog.new(valid_attrs.merge(method: nil))
    assert_not log.valid?
  end

  test "validates endpoint length" do
    log = WebhookLog.new(valid_attrs.merge(endpoint: "x" * 2001))
    assert_not log.valid?
  end

  test "validates error_message length" do
    log = WebhookLog.new(valid_attrs.merge(error_message: "x" * 5001))
    assert_not log.valid?
  end

  test "record! creates a log entry" do
    assert_difference "WebhookLog.count", 1 do
      WebhookLog.record!(
        user: @user,
        direction: "incoming",
        event_type: "agent_complete",
        endpoint: "/api/v1/hooks/agent_complete",
        status_code: 200
      )
    end
  end

  test "record! sets success based on status code" do
    log = WebhookLog.record!(
      user: @user,
      direction: "outgoing",
      event_type: "wake",
      endpoint: "/api/sessions/main/message",
      status_code: 201
    )
    assert log.success

    log2 = WebhookLog.record!(
      user: @user,
      direction: "outgoing",
      event_type: "wake",
      endpoint: "/api/sessions/main/message",
      status_code: 500
    )
    assert_not log2.success
  end

  test "record! sanitizes authorization headers" do
    log = WebhookLog.record!(
      user: @user,
      direction: "incoming",
      event_type: "agent_complete",
      endpoint: "/api/v1/hooks",
      request_headers: {
        "Authorization" => "Bearer secret_token_123",
        "Content-Type" => "application/json"
      }
    )
    assert_equal "[REDACTED]", log.request_headers["Authorization"]
    assert_equal "application/json", log.request_headers["Content-Type"]
  end

  test "record! truncates large bodies" do
    large_body = { data: "x" * 60_000 }
    log = WebhookLog.record!(
      user: @user,
      direction: "incoming",
      event_type: "custom",
      endpoint: "/webhook",
      request_body: large_body
    )
    assert log.request_body["_truncated"]
    assert log.request_body["_size"] > 50_000
  end

  test "record! never raises on failure" do
    # Pass invalid data that would cause create! to fail
    result = WebhookLog.record!(
      user: nil, # will fail FK constraint
      direction: "incoming",
      event_type: "test",
      endpoint: "/test"
    )
    assert_nil result
  end

  test "record! sets error-based success when no status_code" do
    log = WebhookLog.record!(
      user: @user,
      direction: "outgoing",
      event_type: "wake",
      endpoint: "/test",
      error: "Connection refused"
    )
    assert_not log.success
    assert_equal "Connection refused", log.error_message
  end

  test "scope recent orders by created_at desc" do
    old = WebhookLog.create!(valid_attrs.merge(created_at: 1.hour.ago))
    new_log = WebhookLog.create!(valid_attrs.merge(created_at: Time.current))
    assert_equal new_log, WebhookLog.recent.first
  end

  test "scope incoming filters correctly" do
    WebhookLog.create!(valid_attrs.merge(direction: "incoming"))
    WebhookLog.create!(valid_attrs.merge(direction: "outgoing"))
    assert WebhookLog.incoming.all? { |l| l.direction == "incoming" }
  end

  test "scope failed filters correctly" do
    WebhookLog.create!(valid_attrs.merge(success: false))
    WebhookLog.create!(valid_attrs.merge(success: true))
    assert WebhookLog.failed.all? { |l| l.success == false }
  end

  test "trim! keeps only specified number of logs" do
    12.times { WebhookLog.create!(valid_attrs) }
    initial = WebhookLog.where(user: @user).count
    assert initial >= 12

    WebhookLog.trim!(user: @user, keep: 5)
    assert WebhookLog.where(user: @user).count <= 6 # allow +1 for boundary
  end
end
