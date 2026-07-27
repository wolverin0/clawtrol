# frozen_string_literal: true

module Orchestration
  class PayloadSanitizer
    SENSITIVE_KEY = /authorization|cookie|credential|environment|password|secret|token/i
    BEARER_VALUE = /\bBearer\s+[A-Za-z0-9._~+\/=-]{12,}/i
    ASSIGNMENT_VALUE = /\b(?:password|secret|token|api[_-]?key)\s*[:=]\s*\S+/i
    MAX_STRING_LENGTH = 50_000

    def self.call(value)
      new.sanitize(value)
    end

    def self.text(value, maximum: MAX_STRING_LENGTH)
      new.sanitize_text(value, maximum:)
    end

    def sanitize(value)
      case value
      when ActionController::Parameters then sanitize(value.to_unsafe_h)
      when Hash then sanitize_hash(value)
      when Array then value.first(500).map { |item| sanitize(item) }
      when String then sanitize_text(value)
      when Numeric, TrueClass, FalseClass, NilClass then value
      else sanitize_text(value.to_s)
      end
    end

    def sanitize_text(value, maximum: MAX_STRING_LENGTH)
      value.to_s
        .gsub(BEARER_VALUE, "Bearer [REDACTED]")
        .gsub(ASSIGNMENT_VALUE, "[REDACTED]")
        .truncate(maximum)
    end

    private

    def sanitize_hash(value)
      value.each_with_object({}) do |(key, item), result|
        next if key.to_s.match?(SENSITIVE_KEY)

        result[key.to_s] = sanitize(item)
      end
    end
  end
end
