# frozen_string_literal: true

module AgentPlatforms
  # Normalized return value for adapter capability calls.
  #
  # Status taxonomy:
  #   :ok          - call succeeded
  #   :offline     - backend unreachable (missing CLI, timeout, refused conn)
  #   :unsupported - capability not implemented or not exposed by this backend
  #   :error       - backend reached but returned an error
  #
  # Adapters MUST return a Result instead of raising for routine failures
  # (missing CLI, missing config, unsupported capability). Genuine bugs
  # (nil pointer, programming errors) may still raise.
  class Result
    STATUSES = %i[ok offline unsupported error].freeze

    attr_reader :status, :data, :error, :platform

    def initialize(status:, data: nil, error: nil, platform: nil)
      raise ArgumentError, "invalid status #{status}" unless STATUSES.include?(status)
      @status = status
      @data = data
      @error = error
      @platform = platform
    end

    def ok? = status == :ok
    def offline? = status == :offline
    def unsupported? = status == :unsupported
    def error? = status == :error
    def failure? = !ok?

    def to_h
      {
        status: status,
        platform: platform,
        data: data,
        error: error
      }.compact
    end

    def self.ok(data, platform: nil)
      new(status: :ok, data: data, platform: platform)
    end

    def self.offline(error, platform: nil, data: nil)
      new(status: :offline, error: error, platform: platform, data: data)
    end

    def self.unsupported(error = "not supported by this backend", platform: nil, data: nil)
      new(status: :unsupported, error: error, platform: platform, data: data)
    end

    def self.error(error, platform: nil, data: nil)
      new(status: :error, error: error, platform: platform, data: data)
    end
  end
end
