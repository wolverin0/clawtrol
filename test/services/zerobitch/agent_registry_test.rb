# frozen_string_literal: true

require "test_helper"

module Zerobitch
  class AgentRegistryTest < ActiveSupport::TestCase
    def setup
      @registry_path = AgentRegistry::REGISTRY_PATH
      @backup = File.exist?(@registry_path) ? File.read(@registry_path) : nil
      FileUtils.mkdir_p(File.dirname(@registry_path))
      File.write(@registry_path, "[]")
    end

    def teardown
      if @backup.nil?
        FileUtils.rm_f(@registry_path)
      else
        File.write(@registry_path, @backup)
      end
    end

    test "create adds agent with generated id and port" do
      agent = AgentRegistry.create(
        name: "Rex Prime",
        emoji: "🦎",
        role: "Infra",
        provider: "openrouter",
        model: "meta-llama/llama-3.3-70b-instruct:free",
        mode: "daemon"
      )

      assert_equal "rex-prime", agent[:id]
      assert_equal 18_081, agent[:port]
      assert_equal "zeroclaw-rex-prime", agent[:container_name]
      assert_equal "supervised", agent[:autonomy]
      assert agent[:created_at].present?
    end

    test "next_available_port skips used ports" do
      AgentRegistry.create(name: "A", emoji: "A", role: "r", provider: "openrouter", model: "m", mode: "daemon")
      AgentRegistry.create(name: "B", emoji: "B", role: "r", provider: "openrouter", model: "m", mode: "daemon")

      assert_equal 18_083, AgentRegistry.next_available_port
    end

    test "find update destroy flow" do
      created = AgentRegistry.create(name: "Rex", emoji: "🦎", role: "r", provider: "openrouter", model: "m", mode: "daemon")

      found = AgentRegistry.find(created[:id])
      assert_equal created[:id], found[:id]

      updated = AgentRegistry.update(created[:id], role: "infra monitor", mode: "gateway")
      assert_equal "infra monitor", updated[:role]
      assert_equal "gateway", updated[:mode]

      assert AgentRegistry.destroy(created[:id])
      assert_nil AgentRegistry.find(created[:id])
    end

    test "create validates required attrs" do
      assert_raises(ArgumentError) do
        AgentRegistry.create(name: "Missing")
      end
    end
  end
end
