require "test_helper"

class OpenclawMemorySearchHealthServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  FakeResponse = Struct.new(:code, :body, keyword_init: true)

  def with_stubbed_net_http_new(fake)
    original = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) do |_host, _port|
      fake
    end

    yield
  ensure
    Net::HTTP.define_singleton_method(:new) do |host, port|
      original.call(host, port)
    end
  end

  class FakeHTTP
    attr_accessor :use_ssl, :open_timeout, :read_timeout

    def initialize(responses)
      @responses = responses
    end

    def request(req)
      key = [req.method, req.path]
      resp = @responses.fetch(key)
      raise resp if resp.is_a?(Exception)
      resp
    end
  end

  test "returns ok when gateway health + memory search succeed and persists status" do
    user = users(:one)
    user.update!(openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    responses = {
      ["GET", "/health"] => FakeResponse.new(code: "200", body: "{\"ok\":true}"),
      ["POST", "/api/memory/search"] => FakeResponse.new(code: "200", body: "{\"results\":[]}")
    }

    with_stubbed_net_http_new(FakeHTTP.new(responses)) do
      result = OpenclawMemorySearchHealthService.new(user, cache: ActiveSupport::Cache::MemoryStore.new).call
      assert_equal :ok, result.status

      rec = user.reload.openclaw_integration_status
      assert rec.present?
      assert_equal "ok", rec.memory_search_status
      assert rec.memory_search_last_checked_at.present?
    end
  end

  test "returns degraded on 429 and persists last error evidence" do
    user = users(:one)
    user.update!(openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    responses = {
      ["GET", "/health"] => FakeResponse.new(code: "200", body: "{\"ok\":true}"),
      ["POST", "/api/memory/search"] => FakeResponse.new(code: "429", body: "{\"error\":\"RESOURCE_EXHAUSTED\"}")
    }

    with_stubbed_net_http_new(FakeHTTP.new(responses)) do
      result = OpenclawMemorySearchHealthService.new(user, cache: ActiveSupport::Cache::MemoryStore.new).call
      assert_equal :degraded, result.status

      rec = user.reload.openclaw_integration_status
      assert_equal "degraded", rec.memory_search_status
      assert_includes rec.memory_search_last_error, "RESOURCE_EXHAUSTED"
      assert rec.memory_search_last_error_at.present?
    end
  end

  test "returns down when gateway health is unreachable" do
    user = users(:one)
    user.update!(openclaw_gateway_url: "http://example.test", openclaw_gateway_token: "tok")

    responses = {
      ["GET", "/health"] => Errno::ECONNREFUSED.new
    }

    with_stubbed_net_http_new(FakeHTTP.new(responses)) do
      result = OpenclawMemorySearchHealthService.new(user, cache: ActiveSupport::Cache::MemoryStore.new).call
      assert_equal :down, result.status
    end
  end
end
