# frozen_string_literal: true

module SafeLan
  class LegacyExecutionDisabled < StandardError; end

  module LegacyExecutionPolicy
    BLOCKED_PREFIXES = %w[
      /api/v1/hooks
      /api/v1/nightshift
      /api/v1/factory
      /api/v1/openclaw_flows
      /api/v1/gateway
      /api/v1/models
      /zerobitch
      /nightshift
      /factory
      /cronjobs
      /terminal
      /command
      /gateway
      /hooks-dashboard
      /cli-backends
      /model-providers
      /sandbox-config
      /compaction-config
      /heartbeat-config
      /session-reset
      /message-queue
      /dm-policy
      /channel-accounts
      /media-config
      /webchat
      /canvas
      /nodes
      /sessions
      /env_manager
      /telegram_config
      /discord_config
      /logging_config
      /hot_reload
      /channel_config
      /keys
      /skills
      /agents/config
      /exec_approvals
      /identity_links
      /webhooks/mappings
    ].freeze

    BLOCKED_EXACT_PATHS = %w[
      /marketing/generate_image
      /marketing/publish
      /settings/test_connection
    ].freeze

    BLOCKED_ACTIONS = %w[
      spawn_ready
      session_health
      run_debate
      debate_modal
      dispatch_zeroclaw
      run_lobster
      resume_lobster
      spawn_via_gateway
      start_validation
      run_validation
      revalidate
      generate_validation_suggestion
      generate_followup
      enhance_followup
    ].freeze

    BLOCKED_JOB_NAMES = %w[
      AgentAutoRunnerJob
      FactoryCycleTimeoutJob
      FactoryRunnerJob
      FactoryRunnerV2Job
      NightshiftRunnerJob
      NightshiftTimeoutSweeperJob
      OpenclawNotifyJob
      RunDebateJob
      RunValidationJob
      ZerobitchMetricsJob
    ].freeze

    module_function

    def blocked_request?(request)
      return false if test_override?

      path = request.path.to_s
      BLOCKED_EXACT_PATHS.include?(path) ||
        BLOCKED_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") } ||
        BLOCKED_ACTIONS.any? { |action| path.end_with?("/#{action}") } ||
        path.match?(%r{\A/api/v1/workflows/[^/]+/run\z}) ||
        path.match?(%r{\A/api/v1/swarm_ideas/[^/]+/launch\z}) ||
        path.match?(%r{\A/swarm/launch/[^/]+\z})
    end

    def enforce_job!(job_name)
      return unless BLOCKED_JOB_NAMES.include?(job_name.to_s)
      return if test_override?

      raise LegacyExecutionDisabled, "#{job_name} is retired in Safe-LAN mode"
    end

    def test_override?
      Rails.env.test? && ENV["CLAWTROL_TEST_LEGACY_EXECUTION"] == "1"
    end
  end
end
