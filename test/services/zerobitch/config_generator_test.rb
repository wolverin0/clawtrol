# frozen_string_literal: true

require "test_helper"

module Zerobitch
  class ConfigGeneratorTest < ActiveSupport::TestCase
    def setup
      @agent_id = "zb-test-agent"
      @config_dir = Rails.root.join("storage", "zerobitch", "configs", @agent_id)
      @workspace_dir = Rails.root.join("storage", "zerobitch", "workspaces", @agent_id)
      FileUtils.rm_rf(@config_dir)
      FileUtils.rm_rf(@workspace_dir)
    end

    def teardown
      FileUtils.rm_rf(@config_dir)
      FileUtils.rm_rf(@workspace_dir)
    end

    test "generate_config writes config with requested values" do
      path = ConfigGenerator.generate_config(@agent_id, {
        provider: "groq",
        model: "llama-3.3-70b-versatile",
        api_key: "test-key",
        autonomy: "full",
        allowed_commands: ["curl", "docker"],
        gateway_port: 18_081,
        gateway_host: "127.0.0.1"
      })

      content = File.read(path)
      assert_match(/api_key = "test-key"/, content)
      assert_match(/default_provider = "openrouter"/, content)
      assert_match(/default_model = "groq\/llama-3.3-70b-versatile"/, content)
      assert_match(/level = "full"/, content)
      assert_match(/allowed_commands = \["curl","docker"\]/, content)
      assert_match(/port = 18081/, content)
      assert_match(/host = "0.0.0.0"/, content)
      assert_match(/require_pairing = false/, content)
      assert_match(/block_high_risk_commands = false/, content)
    end

    test "generate_workspace writes SOUL and default AGENTS" do
      path = ConfigGenerator.generate_workspace(@agent_id, soul_content: "# Soul")
      assert File.directory?(path)
      assert_equal "# Soul", File.read(path.join("SOUL.md"))
      assert_match(/managed by ZeroBitch Fleet/i, File.read(path.join("AGENTS.md")))
    end

    test "resolve_provider maps friendly names" do
      assert_equal "openrouter", ConfigGenerator.resolve_provider("groq")
      assert_equal "custom:https://api.cerebras.ai/v1", ConfigGenerator.resolve_provider("cerebras")
      assert_equal "custom:https://api.mistral.ai/v1", ConfigGenerator.resolve_provider("mistral")
      assert_equal "ollama", ConfigGenerator.resolve_provider("ollama")
    end
  end
end
