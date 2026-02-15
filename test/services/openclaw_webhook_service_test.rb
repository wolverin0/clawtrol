# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class OpenclawWebhookServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @user.update_columns(
      openclaw_gateway_url: "http://localhost:18080",
      openclaw_gateway_token: "test-token-123"
    )
    @board = boards(:default)
    @task = @board.tasks.create!(
      name: "Test webhook task",
      user: @user,
      status: :up_next,
      assigned_to_agent: true
    )
  end

  # --- configured? checks ---

  test "does nothing when gateway URL is blank" do
    @user.update_columns(openclaw_gateway_url: nil)
    service = OpenclawWebhookService.new(@user.reload)
    assert_nil service.notify_task_assigned(@task)
  end

  test "does nothing when gateway token is blank" do
    @user.update_columns(openclaw_gateway_token: nil, openclaw_hooks_token: nil)
    service = OpenclawWebhookService.new(@user.reload)
    assert_nil service.notify_task_assigned(@task)
  end

  test "does nothing when gateway URL contains example" do
    @user.update_columns(openclaw_gateway_url: "http://example.com/gateway")
    service = OpenclawWebhookService.new(@user.reload)
    assert_nil service.notify_task_assigned(@task)
  end

  test "does nothing when both URL and token are blank" do
    @user.update_columns(openclaw_gateway_url: "", openclaw_gateway_token: "")
    service = OpenclawWebhookService.new(@user.reload)
    assert_nil service.notify_task_assigned(@task)
  end

  # --- notify_task_assigned message format ---

  test "notify_task_assigned sends Execute Now message" do
    sent_body = nil
    mock_http = mock_successful_http { |body| sent_body = body }

    Net::HTTP.stub(:new, ->(_host, _port) { mock_http }) do
      service = OpenclawWebhookService.new(@user)
      service.notify_task_assigned(@task)
    end

    assert_not_nil sent_body
    parsed = JSON.parse(sent_body)
    assert_equal "Execute Now: Test webhook task", parsed["text"]
    assert_equal "now", parsed["mode"]
  end

  # --- notify_auto_claimed message format ---

  test "notify_auto_claimed sends auto-claimed message with task id" do
    sent_body = nil
    mock_http = mock_successful_http { |body| sent_body = body }

    Net::HTTP.stub(:new, ->(_host, _port) { mock_http }) do
      service = OpenclawWebhookService.new(@user)
      service.notify_auto_claimed(@task)
    end

    parsed = JSON.parse(sent_body)
    assert_includes parsed["text"], "Auto-claimed task ##{@task.id}"
    assert_includes parsed["text"], "Test webhook task"
  end

  # --- notify_auto_pull_ready message format ---

  test "notify_auto_pull_ready includes model name" do
    @task.update_columns(model: "opus")
    sent_body = nil
    mock_http = mock_successful_http { |body| sent_body = body }

    Net::HTTP.stub(:new, ->(_host, _port) { mock_http }) do
      service = OpenclawWebhookService.new(@user)
      service.notify_auto_pull_ready(@task)
    end

    parsed = JSON.parse(sent_body)
    assert_includes parsed["text"], "model: opus"
  end

  test "notify_auto_pull_ready uses default model when task has none" do
    @task.update_columns(model: nil)
    sent_body = nil
    mock_http = mock_successful_http { |body| sent_body = body }

    Net::HTTP.stub(:new, ->(_host, _port) { mock_http }) do
      service = OpenclawWebhookService.new(@user)
      service.notify_auto_pull_ready(@task)
    end

    parsed = JSON.parse(sent_body)
    assert_includes parsed["text"], "model: #{Task::DEFAULT_MODEL}"
  end

  # --- Auth token preference ---

  test "prefers hooks_token over gateway_token" do
    @user.update_columns(openclaw_hooks_token: "hooks-token-456")
    auth_header = nil
    mock_http = mock_successful_http { }
    # Capture the Authorization header
    original_new = Net::HTTP::Post.method(:new)
    Net::HTTP::Post.stub(:new, ->(*args) {
      req = original_new.call(*args)
      req.define_singleton_method(:original_body=) { |b| }
      req
    }) do
      # Simpler: just test the service builds correctly
    end

    # Test via direct inspection of the service's auth_token method
    service = OpenclawWebhookService.new(@user.reload)
    assert_equal "hooks-token-456", service.send(:auth_token)
  end

  test "falls back to gateway_token when hooks_token is blank" do
    @user.update_columns(openclaw_hooks_token: nil)
    service = OpenclawWebhookService.new(@user.reload)
    assert_equal "test-token-123", service.send(:auth_token)
  end

  # --- Error resilience ---

  test "returns nil and does not raise on connection refused" do
    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [false])
    mock_http.expect(:open_timeout=, nil, [5])
    mock_http.expect(:read_timeout=, nil, [5])
    # All 3 attempts raise connection refused
    3.times do
      mock_http.expect(:request, nil) { raise Errno::ECONNREFUSED }
    end

    Net::HTTP.stub(:new, ->(_host, _port) { mock_http }) do
      service = OpenclawWebhookService.new(@user)
      result = service.notify_task_assigned(@task)
      assert_nil result
    end
  end

  private

  def mock_successful_http(&on_request)
    response = Minitest::Mock.new
    response.expect(:code, "200")
    response.expect(:code, "200")
    response.expect(:code, "200")

    http = Minitest::Mock.new
    http.expect(:use_ssl=, nil, [false])
    http.expect(:open_timeout=, nil, [5])
    http.expect(:read_timeout=, nil, [5])
    http.expect(:request, response) do |req|
      on_request&.call(req.body)
      true
    end

    http
  end
end
