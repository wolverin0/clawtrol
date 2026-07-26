# frozen_string_literal: true

module AgentPlatforms
  # Central lookup for AgentPlatform adapters.
  #
  # Controllers/services that need to act on a backend should ask the registry
  # rather than naming a concrete adapter, so dual-mode and future backends
  # work without touching call sites.
  #
  # Identity rules:
  #   - registered platforms live in PLATFORMS
  #   - "openclaw" is always the safe default
  #   - registry never raises for missing/invalid keys; it falls back to openclaw
  module Registry
    module_function

    PLATFORMS = %w[openclaw hermes].freeze
    DEFAULT_PLATFORM = "openclaw"

    # Resolve an adapter for a given user + explicit platform key.
    # Falls back to user.effective_agent_platform, then to default.
    def for(user, platform: nil)
      enabled = enabled_platforms(user)
      preferred = normalize(user.try(:effective_agent_platform))
      explicit = normalize(platform)
      key = [explicit, preferred, enabled.first, DEFAULT_PLATFORM].find { |candidate| enabled.include?(candidate) } || DEFAULT_PLATFORM
      adapter_class_for(key).new(user)
    end

    def for_default(user)
      self.for(user)
    end

    def available_for(user)
      enabled_platforms(user).map { |k| adapter_class_for(k).new(user) }
    end

    # Returns platform keys the user has opted into based on orchestration_mode.
    def enabled_platforms(user)
      case user.try(:orchestration_mode)
      when "hermes_only" then %w[hermes]
      when "dual"        then PLATFORMS
      else                    %w[openclaw]
      end
    end

    def adapter_class_for(key)
      case normalize(key)
      when "hermes"   then HermesAdapter
      when "openclaw" then OpenclawAdapter
      else                 OpenclawAdapter
      end
    end

    def normalize(key)
      return nil if key.nil?
      str = key.to_s.strip.downcase
      PLATFORMS.include?(str) ? str : nil
    end
  end
end
