# frozen_string_literal: true

# Shared status, frequency, and category constants for domain models.
# Use `extend StatusConstants` in models to include these constants.
module StatusConstants
  extend ActiveSupport::Concern

  # Common statuses
  module Status
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    ACTIVE = "active"
    RESOLVED = "resolved"
    REGRESSED = "regressed"
    IDLE = "idle"
    PLAYING = "playing"
    PAUSED = "paused"
    STOPPED = "stopped"
    VERIFIED = "verified"
    RECORDED = "recorded"

    ALL = [PENDING, RUNNING, COMPLETED, FAILED, ACTIVE, RESOLVED, REGRESSED, IDLE, PLAYING, PAUSED, STOPPED, VERIFIED, RECORDED].freeze
  end

  # Common frequencies
  module Frequency
    ALWAYS = "always"
    WEEKLY = "weekly"
    ONE_TIME = "one_time"
    AUTO_GENERATED = "auto_generated"
    MANUAL = "manual"

    ALL = [ALWAYS, WEEKLY, ONE_TIME, AUTO_GENERATED, MANUAL].freeze
  end

  # Common categories
  module Category
    GENERAL = "general"
    INFRA = "infra"
    SECURITY = "security"
    RESEARCH = "research"
    CODE = "code"
    FINANCE = "finance"
    SOCIAL = "social"
    NETWORK = "network"
    MARKETING = "marketing"
    FITNESS = "fitness"
    PERSONAL = "personal"

    ALL = [GENERAL, INFRA, SECURITY, RESEARCH, CODE, FINANCE, SOCIAL, NETWORK, MARKETING, FITNESS, PERSONAL].freeze
  end
end
