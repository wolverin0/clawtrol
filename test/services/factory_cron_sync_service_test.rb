# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class FactoryCronSyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "factory-cron-sync@example.com", password: "password123456")
  end

  test "create_cron posts job and stores returned cron id" do
    with_loop_and_agent do |loop|
      with_env("OPENCLAW_GATEWAY_URL" => "http://localhost:18789", "OPENCLAW_GATEWAY_TOKEN" => "token-123") do
        requests = []
        responses = [ { code: "200", body: { id: "cron-abc-123" }.to_json } ]

        with_stubbed_http(requests:, responses:) do
          result = FactoryCronSyncService.create_cron(loop)

          assert_equal "cron-abc-123", result["id"]
          assert_equal "cron-abc-123", loop.reload.openclaw_cron_id
          assert_equal 1, requests.size

          req = requests.first
          assert_equal "POST", req[:method]
          assert_equal "/api/cron/jobs", req[:path]
          assert_equal "Bearer token-123", req[:headers]["Authorization"]&.first
          assert_equal true, req[:json]["enabled"]
          assert_equal "isolated", req[:json]["sessionTarget"]
          assert_equal 120_000, req[:json].dig("schedule", "everyMs")
          assert_equal "ollama/minimax-m2.5:cloud", req[:json].dig("payload", "model")
          assert_includes req[:json].dig("payload", "message"), "Workspace: #{loop.workspace_path}"
          assert_equal (loop.max_session_minutes * 60) - 60, req[:json].dig("payload", "timeoutSeconds")
        end
      end
    end
  end

  test "pause_cron sends patch enabled false" do
    loop = build_loop(openclaw_cron_id: "cron-1")

    with_env("OPENCLAW_GATEWAY_URL" => "http://localhost:18789", "OPENCLAW_GATEWAY_TOKEN" => "token-123") do
      requests = []
      responses = [ { code: "200", body: { ok: true }.to_json } ]

      with_stubbed_http(requests:, responses:) do
        FactoryCronSyncService.pause_cron(loop)
      end

      assert_equal "PATCH", requests.first[:method]
      assert_equal "/api/cron/jobs/cron-1", requests.first[:path]
      assert_equal false, requests.first[:json]["enabled"]
    end
  end

  test "resume_cron sends patch enabled true" do
    loop = build_loop(openclaw_cron_id: "cron-2")

    with_env("OPENCLAW_GATEWAY_URL" => "http://localhost:18789", "OPENCLAW_GATEWAY_TOKEN" => "token-123") do
      requests = []
      responses = [ { code: "200", body: { ok: true }.to_json } ]

      with_stubbed_http(requests:, responses:) do
        FactoryCronSyncService.resume_cron(loop)
      end

      assert_equal "PATCH", requests.first[:method]
      assert_equal "/api/cron/jobs/cron-2", requests.first[:path]
      assert_equal true, requests.first[:json]["enabled"]
    end
  end

  test "delete_cron deletes remote job and clears openclaw_cron_id" do
    loop = build_loop(openclaw_cron_id: "cron-3")

    with_env("OPENCLAW_GATEWAY_URL" => "http://localhost:18789", "OPENCLAW_GATEWAY_TOKEN" => "token-123") do
      requests = []
      responses = [ { code: "200", body: { ok: true }.to_json } ]

      with_stubbed_http(requests:, responses:) do
        FactoryCronSyncService.delete_cron(loop)
      end

      assert_equal "DELETE", requests.first[:method]
      assert_equal "/api/cron/jobs/cron-3", requests.first[:path]
      assert_nil loop.reload.openclaw_cron_id
    end
  end

  private

  def build_loop(attrs = {})
    FactoryLoop.create!({
      name: "Factory Cron #{SecureRandom.hex(3)}",
      slug: "factory-cron-#{SecureRandom.hex(4)}",
      interval_ms: 120_000,
      model: "minimax",
      status: "idle",
      workspace_path: Dir.mktmpdir,
      max_session_minutes: 180,
      user: @user
    }.merge(attrs))
  end

  def with_loop_and_agent
    loop = build_loop
    agent = FactoryAgent.create!(
      name: "Agent #{SecureRandom.hex(2)}",
      slug: "agent-#{SecureRandom.hex(4)}",
      category: "code-quality",
      system_prompt: "Keep improving safely",
      run_condition: "always",
      cooldown_hours: 1,
      default_confidence_threshold: 80,
      priority: 1
    )
    FactoryLoopAgent.create!(factory_loop: loop, factory_agent: agent, enabled: true)

    yield loop
  end

  def with_env(values)
    originals = values.transform_values { nil }
    values.each_key { |k| originals[k] = ENV[k] }
    values.each { |k, v| ENV[k] = v }
    yield
  ensure
    originals.each { |k, v| ENV[k] = v }
  end

  def with_stubbed_http(requests:, responses:)
    original_new = Net::HTTP.method(:new)

    Net::HTTP.define_singleton_method(:new) do |_host, _port|
      http = Object.new
      http.define_singleton_method(:use_ssl=) { |_value| }
      http.define_singleton_method(:open_timeout=) { |_value| }
      http.define_singleton_method(:read_timeout=) { |_value| }
      http.define_singleton_method(:request) do |req|
        requests << {
          method: req.method,
          path: req.path,
          headers: req.to_hash.transform_keys { |k| k.split("-").map(&:capitalize).join("-") },
          json: req.body.present? ? JSON.parse(req.body) : {}
        }

        payload = responses.shift || { code: "200", body: "{}" }
        Struct.new(:code, :body).new(payload[:code], payload[:body])
      end
      http
    end

    yield
  ensure
    Net::HTTP.define_singleton_method(:new) { |*args, &blk| original_new.call(*args, &blk) }
  end
end
