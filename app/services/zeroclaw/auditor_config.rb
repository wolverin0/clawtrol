# frozen_string_literal: true

module Zeroclaw
  class AuditorConfig
    class << self
      def enabled?
        env_bool("ZEROCLAW_AUDITOR_ENABLED", true)
      end

      def auto_done?
        env_bool("ZEROCLAW_AUDITOR_AUTO_DONE", false)
      end

      def max_rework_loops
        Integer(ENV.fetch("ZEROCLAW_AUDITOR_MAX_REWORK_LOOPS", "2"))
      rescue ArgumentError
        2
      end

      def auditable_tags
        ENV.fetch("ZEROCLAW_AUDITOR_TAGS", "coding,research,infra,report")
          .split(",")
          .map(&:strip)
          .reject(&:blank?)
      end

      def llm_model
        ENV.fetch("ZEROCLAW_AUDITOR_MODEL", "openai-codex/gpt-5.3-codex")
      end

      def mode
        ENV.fetch("ZEROCLAW_AUDITOR_MODE", "rule_based")
      end

      def min_interval_seconds
        Integer(ENV.fetch("ZEROCLAW_AUDITOR_MIN_INTERVAL_SECONDS", "300"))
      rescue ArgumentError
        300
      end

      def sweep_limit
        Integer(ENV.fetch("ZEROCLAW_AUDITOR_SWEEP_LIMIT", "100"))
      rescue ArgumentError
        100
      end

      def sweep_lookback_hours
        Integer(ENV.fetch("ZEROCLAW_AUDITOR_SWEEP_LOOKBACK_HOURS", "168"))
      rescue ArgumentError
        168
      end

      private

      def env_bool(key, default)
        raw = ENV[key]
        return default if raw.nil?

        %w[1 true yes on].include?(raw.to_s.strip.downcase)
      end
    end
  end
end
