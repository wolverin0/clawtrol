# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class AgentAutoRunnerHealthGateTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  class FakeWebhookService
    cattr_accessor :wakes, default: []

    def initialize(_user)
    end

    def notify_auto_pull_ready(task)
      self.class.wakes << task.id
      true
    end

    def notify_auto_pull_ready_with_pipeline(task)
      self.class.wakes << task.id
      true
    end

    def notify_runner_summary(_message)
      true
    end
  end

  setup do
    Rails.cache.clear
    User.update_all(agent_auto_mode: false)
    @user = User.create!(
      email_address: "auto_runner_health_#{SecureRandom.hex(4)}@example.test",
      password: "password123",
      password_confirmation: "password123",
      agent_auto_mode: true,
      openclaw_gateway_url: "http://example.test",
      openclaw_gateway_token: "tok"
    )
    @board = Board.create!(user: @user, name: "Health Gate Board")
    @task = Task.create!(
      user: @user,
      board: @board,
      name: "Health Gate Task",
      status: :up_next,
      assigned_to_agent: true,
      blocked: false,
      pipeline_enabled: false,
      model: "gemini"
    )
  end

  test "gateway 503 skips wakes and records skip reason" do
    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    with_healthcheck_enabled do
      stub_gateway_ready(503) do
        travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
          stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
          assert_equal 0, FakeWebhookService.wakes.length
          assert_equal 1, stats[:queue_skip_reasons][:gateway_not_ready]
        end
      end
    end
  end

  test "gateway 200 allows wakes" do
    FakeWebhookService.wakes = []
    cache = ActiveSupport::Cache::MemoryStore.new

    with_healthcheck_enabled do
      stub_gateway_ready(200) do
        travel_to Time.find_zone!("America/Argentina/Buenos_Aires").local(2026, 2, 8, 23, 30, 0) do
          stats = AgentAutoRunnerService.new(openclaw_webhook_service: FakeWebhookService, cache: cache).run!
          assert_includes FakeWebhookService.wakes, @task.id
          assert stats[:tasks_woken] >= 1
        end
      end
    end
  end

  private

  def with_healthcheck_enabled
    original = ENV["OPENCLAW_GATEWAY_HEALTHCHECK"]
    ENV["OPENCLAW_GATEWAY_HEALTHCHECK"] = "true"
    yield
  ensure
    ENV["OPENCLAW_GATEWAY_HEALTHCHECK"] = original
  end

  def stub_gateway_ready(code)
    response = Minitest::Mock.new
    response.expect(:code, code.to_s)

    http = Minitest::Mock.new
    http.expect(:use_ssl=, nil, [false])
    http.expect(:open_timeout=, nil, [3])
    http.expect(:read_timeout=, nil, [3])
    http.expect(:request, response) { true }

    Net::HTTP.stub(:new, ->(_host, _port) { http }) do
      yield
    end
  ensure
    response.verify
    http.verify
  end
end
