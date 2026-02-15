# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Api::RateLimitableTest < ActiveSupport::TestCase
  # Test the concern in isolation using a mock controller-like object

  class FakeController
    include Api::RateLimitable

    attr_accessor :current_user_obj, :remote_ip_val, :response_headers,
                  :controller_path_val, :action_name_val, :rendered

    def initialize
      @response_headers = {}
      @controller_path_val = "api/v1/test"
      @action_name_val = "index"
      @remote_ip_val = "127.0.0.1"
      @rendered = nil
    end

    def response
      @response_obj ||= Struct.new(:headers).new(response_headers)
      def @response_obj.set_header(key, val)
        headers[key] = val
      end
      @response_obj
    end

    def request
      @request_obj ||= Struct.new(:remote_ip).new(remote_ip_val)
    end

    def controller_path
      controller_path_val
    end

    def action_name
      action_name_val
    end

    def render(json:, status:)
      @rendered = { json: json, status: status }
    end

    # Expose private method for testing
    def test_rate_limit!(limit:, window:, key_suffix: nil)
      @current_user = current_user_obj
      rate_limit!(limit: limit, window: window, key_suffix: key_suffix)
    end

    def test_identifier
      @current_user = current_user_obj
      rate_limit_identifier
    end
  end

  setup do
    @controller = FakeController.new
    # Test env uses :null_store — rate limiting needs a real cache store
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "rate_limit_identifier returns user:id for authenticated" do
    @controller.current_user_obj = OpenStruct.new(id: 42)
    assert_equal "user:42", @controller.test_identifier
  end

  test "rate_limit_identifier returns ip for anonymous" do
    @controller.current_user_obj = nil
    assert_equal "ip:127.0.0.1", @controller.test_identifier
  end

  test "allows requests within limit" do
    @controller.current_user_obj = OpenStruct.new(id: 1)
    3.times { @controller.test_rate_limit!(limit: 5, window: 60) }
    assert_nil @controller.rendered
    assert_equal "5", @controller.response_headers["X-RateLimit-Limit"]
    assert @controller.response_headers["X-RateLimit-Remaining"].to_i >= 2
  end

  test "blocks requests over limit with 429" do
    Rails.cache.clear
    ctrl = FakeController.new
    ctrl.current_user_obj = OpenStruct.new(id: 99)
    # Call one-by-one and check the count progression
    5.times { ctrl.test_rate_limit!(limit: 5, window: 60) }
    assert_nil ctrl.rendered, "Should NOT render for first 5 calls"
    # 6th call should trigger 429
    ctrl.test_rate_limit!(limit: 5, window: 60)
    assert_not_nil ctrl.rendered, "Expected 429 render on 6th call (limit=5). Headers: #{ctrl.response_headers.inspect}"
    assert_equal :too_many_requests, ctrl.rendered[:status]
    assert_equal "Rate limit exceeded", ctrl.rendered[:json][:error]
    assert_equal "60", ctrl.response_headers["Retry-After"]
  end

  test "different key_suffixes are independent" do
    @controller.current_user_obj = OpenStruct.new(id: 1)
    5.times { @controller.test_rate_limit!(limit: 5, window: 60, key_suffix: "a") }
    @controller.rendered = nil
    @controller.test_rate_limit!(limit: 5, window: 60, key_suffix: "b")
    assert_nil @controller.rendered # "b" bucket is fresh
  end

  test "different users have independent limits" do
    @controller.current_user_obj = OpenStruct.new(id: 1)
    5.times { @controller.test_rate_limit!(limit: 5, window: 60) }

    @controller.rendered = nil
    @controller.current_user_obj = OpenStruct.new(id: 2)
    @controller.test_rate_limit!(limit: 5, window: 60)
    assert_nil @controller.rendered # user 2 is fresh
  end
end
