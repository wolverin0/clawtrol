# frozen_string_literal: true

module Zeroclaw
  module AuditableTask
    PIPELINE_TYPES = %w[feature bug-fix quick-fix research].freeze

    module_function

    def auditable?(task)
      tags = Array(task.tags).map { |tag| tag.to_s.downcase }
      configured_tags = AuditorConfig.auditable_tags

      tags.any? { |tag| configured_tags.include?(tag) } ||
        PIPELINE_TYPES.include?(task.pipeline_type.to_s.downcase)
    end

    def last_completed_at(task)
      state_data = task.state_data.is_a?(Hash) ? task.state_data : {}
      raw = state_data.dig("auditor", "last", "completed_at")
      return nil if raw.blank?

      Time.zone.parse(raw.to_s)
    rescue StandardError
      nil
    end

    def recently_audited?(task, min_interval_seconds: AuditorConfig.min_interval_seconds)
      last_completed = last_completed_at(task)
      return false unless last_completed

      (Time.current - last_completed) < min_interval_seconds.to_i
    end
  end
end
