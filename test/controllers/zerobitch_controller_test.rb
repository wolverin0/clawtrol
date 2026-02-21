# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "securerandom"

class ZerobitchControllerTest < ActionDispatch::IntegrationTest
  parallelize(workers: 1)

  setup do
    @user = users(:one)
    sign_in_as(@user)
    @cleanup_paths = []
  end

  teardown do
    @cleanup_paths.each do |path|
      FileUtils.rm_rf(path)
    end
  end

  test "index renders agent cards with template and observability blocks" do
    agent = sample_agent(id: "rex")
    write_agent_config(agent[:id], <<~TOML)
      [observability]
      backend = "log"
      otel_endpoint = "http://otel-collector:4318/v1/traces"
    TOML

    with_stubbed_fleet(agent) do
      get zerobitch_path
    end

    assert_response :success
    assert_includes response.body, "Prompt template"
    assert_includes response.body, "Observability:"
    assert_includes response.body, "data-template-editor"
    assert_includes response.body, "📜 Logs"
  end

  test "metrics returns observability and cron telemetry payload" do
    agent = sample_agent(id: "rex")
    write_agent_config(agent[:id], <<~TOML)
      [observability]
      backend = "log"
      otel_endpoint = "http://otel-collector:4318/v1/traces"
      service_name = "zeroclaw-rex"
    TOML

    with_stubbed_fleet(agent) do
      get zerobitch_metrics_path(format: :json)
    end

    assert_response :success
    payload = JSON.parse(response.body)

    assert_equal 1, payload.dig("summary", "total")
    assert_equal 7, payload.dig("summary", "tasks_today")

    first = payload.fetch("agents").first
    assert_equal "running", first["status"]
    assert_equal "native", first["cron_source"]
    assert_equal "log", first.dig("observability", "backend")
    assert_equal "http://otel-collector:4318/v1/traces", first.dig("observability", "otel_endpoint")
    assert_equal 2, first["restart_count"]
  end

  test "save_template updates template via json" do
    agent = sample_agent(id: "rex", template: "old template")

    Zerobitch::AgentRegistry.stub(:find, agent) do
      Zerobitch::AgentRegistry.stub(:update, agent.merge(template: "new template")) do
        patch zerobitch_agent_template_path(agent[:id]), params: { template: "new template" }, as: :json
      end
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["ok"]
    assert_equal "new template", payload["template"]
  end

  private

  def sample_agent(id:, template: "You are a focused operator")
    {
      id: id,
      name: "Rex",
      emoji: "🦎",
      role: "Network ops",
      description: "Keeps infra stable",
      provider: "zai",
      model: "glm-4.7",
      container_name: "zeroclaw-#{id}",
      template: template,
      cron_schedule: ["*/5 * * * * ping"],
      skillforge: true
    }
  end

  def with_stubbed_fleet(agent)
    docker_agents = [{ name: agent[:container_name], state: "running", status: "Up 1 hour" }]
    docker_stats = { mem_usage: "12.1MiB", mem_limit: "64MiB", mem_percent: "18.9%", cpu_percent: "1.1%" }
    docker_state = { status: "running", restart_count: 2, started_at: 1.hour.ago.iso8601 }
    cron_json = { jobs: [{ name: "heartbeat", schedule: "*/5 * * * *", enabled: true }] }.to_json

    Zerobitch::AgentRegistry.stub(:all, [agent]) do
      Zerobitch::DockerService.stub(:list_agents, docker_agents) do
        Zerobitch::DockerService.stub(:container_stats, docker_stats) do
          Zerobitch::DockerService.stub(:container_state, docker_state) do
            Zerobitch::DockerService.stub(:cron_list, { success: true, output: cron_json }) do
              Zerobitch::MetricsStore.stub(:collect_all, true) do
                Zerobitch::MetricsStore.stub(:all_histories, { agent[:id] => [{ "mem" => 10 }, { "mem" => 12 }] }) do
                  Zerobitch::MetricsStore.stub(:tasks_today, 7) do
                    Zerobitch::TaskHistory.stub(:all, []) do
                      yield
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def write_agent_config(agent_id, content)
    dir = Rails.root.join("storage", "zerobitch", "configs", agent_id)
    FileUtils.mkdir_p(dir)
    File.write(dir.join("config.toml"), content)
    @cleanup_paths << dir
  end
end
