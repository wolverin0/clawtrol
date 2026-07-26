# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class AgentPlatforms::HermesCliRunnerTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @user.update!(hermes_home: "~/.hermes", hermes_profile: nil)
  end

  test "returns offline result when hermes binary is missing" do
    with_env("HERMES_CLI_PATH" => "/nonexistent/hermes-binary-#{SecureRandom.hex(4)}") do
      runner = AgentPlatforms::HermesCliRunner.new(@user)
      result = runner.run("--version")

      assert_equal :offline, result[:status]
      assert_equal 127, result[:exitstatus]
      assert_match(/hermes/i, result[:stderr])
    end
  end

  test "run_json returns offline marker hash when binary missing" do
    with_env("HERMES_CLI_PATH" => "/nonexistent/hermes-binary-#{SecureRandom.hex(4)}") do
      runner = AgentPlatforms::HermesCliRunner.new(@user)
      parsed = runner.run_json("sessions", "list", "--json", label: "hermes sessions")
      assert_equal "offline", parsed["status"]
      assert parsed["error"].present?
    end
  end

  test "run_json returns unsupported on invalid JSON when CLI succeeds" do
    with_env("HERMES_CLI_PATH" => "/bin/echo") do
      runner = AgentPlatforms::HermesCliRunner.new(@user)
      parsed = runner.run_json("not-json-output", label: "echo")
      assert_equal "unsupported", parsed["status"]
    end
  end

  test "HermesAdapter health surfaces offline result when CLI missing" do
    with_env("HERMES_CLI_PATH" => "/nonexistent/hermes-#{SecureRandom.hex(4)}") do
      adapter = AgentPlatforms::HermesAdapter.new(@user)
      result = adapter.health
      assert result.offline?, "expected offline, got #{result.status} (#{result.error})"
      assert_equal "hermes", result.platform
    end
  end

  test "HermesAdapter sessions_list returns offline Result when CLI missing" do
    with_env("HERMES_CLI_PATH" => "/nonexistent/hermes-#{SecureRandom.hex(4)}") do
      adapter = AgentPlatforms::HermesAdapter.new(@user)
      result = adapter.sessions_list
      assert result.offline?, "expected offline, got #{result.status} (#{result.error})"
    end
  end

  test "HermesAdapter inherits unsupported result for write operations" do
    adapter = AgentPlatforms::HermesAdapter.new(@user)
    assert adapter.cron_create({}).unsupported?
    assert adapter.cron_update("id", {}).unsupported?
    assert adapter.cron_delete("id").unsupported?
    assert adapter.sessions_send("key", "msg").unsupported?
  end

  test "HermesAdapter config_get is unsupported to avoid leaking credentials" do
    adapter = AgentPlatforms::HermesAdapter.new(@user)
    result = adapter.config_get

    assert result.unsupported?
    assert_match(/credentials/i, result.error)
  end

  test "HermesAdapter file_roots uses dedicated viewer artifact root" do
    with_env("HERMES_VIEWER_DIR" => "/tmp/hermes-artifacts-#{SecureRandom.hex(4)}") do
      adapter = AgentPlatforms::HermesAdapter.new(@user)
      assert_equal ENV.fetch("HERMES_VIEWER_DIR"), adapter.file_roots.fetch("hermes").to_s
    end
  end

  test "HermesAdapter file_roots defaults below artifacts, not raw hermes home" do
    with_env("HERMES_VIEWER_DIR" => nil) do
      adapter = AgentPlatforms::HermesAdapter.new(@user)
      assert_equal File.expand_path("~/.hermes/artifacts"), adapter.file_roots.fetch("hermes").to_s
      assert_not_equal File.expand_path("~/.hermes"), adapter.file_roots.fetch("hermes").to_s
    end
  end

  private

  def with_env(overrides)
    saved = {}
    overrides.each do |k, v|
      saved[k] = ENV[k]
      ENV[k] = v
    end
    yield
  ensure
    saved.each { |k, v| ENV[k] = v }
  end
end
