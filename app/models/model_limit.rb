# frozen_string_literal: true

# Tracks rate limits for AI models per user
# Used for auto-fallback when a model hits its limit
class ModelLimit < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :name, inclusion: { in: Task::MODELS }
  validates :name, uniqueness: { scope: :user_id }
  validates :limit_tokens, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :resets_at, presence: true, if: -> { limited? }
  validates :error_message, length: { maximum: 1000 }, allow_nil: true

  scope :limited, -> { where(limited: true) }
  scope :available, -> { where(limited: false).or(where("resets_at <= ?", Time.current)) }
  scope :active_limits, -> { where(limited: true).where("resets_at > ?", Time.current) }

  # Model priority order for fallback (highest to lowest)
  # Codex is preferred but rate-limited, Opus is always available with Max subscription
  MODEL_PRIORITY = %w[codex opus sonnet glm].freeze

  # Check if this limit is currently active (not expired)
  def active_limit?
    limited? && resets_at.present? && resets_at > Time.current
  end

  # Clear the limit (either manually or when reset time passes)
  def clear!
    update!(limited: false, resets_at: nil, error_message: nil)
  end

  # Set a rate limit with reset time
  def set_limit!(error_message:, resets_at: nil)
    update!(
      limited: true,
      resets_at: resets_at,
      error_message: error_message,
      last_error_at: Time.current
    )
  end

  # Time until reset in human-readable format
  def time_until_reset
    return nil unless resets_at.present? && resets_at > Time.current

    seconds = (resets_at - Time.current).to_i
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m"
    elsif seconds < 86400
      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    else
      "#{seconds / 86400}d #{(seconds % 86400) / 3600}h"
    end
  end

  # Class methods for model limit management
  class << self
    # Get or create a model limit record for a user/model combo
    def for_model(user, name)
      find_or_create_by(user: user, name: name)
    end

    # Check if a model is available for a user
    def model_available?(user, name)
      limit = find_by(user: user, name: name)
      return true if limit.nil?  # No limit record = available
      !limit.active_limit?
    end

    # Get the best available model based on priority
    # Returns [name, fallback_note] where fallback_note is nil if requested model is available
    def best_available_model(user, requested_model = nil)
      # If no model requested, use priority order
      models_to_try = if requested_model.present?
        # Put requested model first, then priority order
        ([requested_model] + MODEL_PRIORITY).uniq
      else
        MODEL_PRIORITY
      end

      fallback_note = nil
      selected_model = nil

      models_to_try.each_with_index do |model, index|
        if model_available?(user, model)
          selected_model = model
          # If we had to fall back from the requested model, note it
          if index > 0 && requested_model.present? && requested_model != model
            original_limit = find_by(user: user, name: requested_model)
            reset_info = original_limit&.resets_at&.strftime("%b %d %H:%M") || "unknown"
            fallback_note = "⚠️ #{requested_model.capitalize} rate-limited (resets #{reset_info}), using #{model.capitalize} instead"
          end
          break
        end
      end

      # If all models are limited, just use the first priority model and note the issue
      if selected_model.nil?
        selected_model = MODEL_PRIORITY.first
        fallback_note = "⚠️ All models rate-limited, attempting #{selected_model.capitalize} anyway"
      end

      [selected_model, fallback_note]
    end

    # Record a rate limit from an error message
    # Parses reset time from common error formats
    def record_limit!(user, name, error_message)
      limit = for_model(user, name)

      # Try to parse reset time from error message
      # Common formats:
      # - "Rate limit exceeded. Resets at 2026-02-09T23:09:00Z"
      # - "Rate limit exceeded. Try again at 2026-02-09 23:09:00"
      # - "Rate limit exceeded. Retry after 3600 seconds"
      resets_at = parse_reset_time(error_message)

      limit.set_limit!(error_message: error_message, resets_at: resets_at)
      limit
    end

    # Clear expired limits for all users (can be called periodically)
    def clear_expired_limits!
      where(limited: true)
        .where("resets_at IS NOT NULL AND resets_at <= ?", Time.current)
        .update_all(limited: false)
    end

    private

    def parse_reset_time(error_message)
      return nil if error_message.blank?

      # Try ISO 8601 format: "Resets at 2026-02-09T23:09:00Z"
      if error_message =~ /resets?\s+at\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[Z\+\-\d:]*)/i
        return Time.parse($1) rescue nil
      end

      # Try "Try again at" format: "Try again at 2026-02-09 23:09:00"
      if error_message =~ /try\s+again\s+at\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})/i
        return Time.parse($1) rescue nil
      end

      # Try "Retry after N seconds" format
      if error_message =~ /retry\s+after\s+(\d+)\s*(?:seconds?|secs?|s)?/i
        seconds = $1.to_i
        return Time.current + seconds.seconds if seconds > 0
      end

      # Try "wait N minutes" format
      if error_message =~ /wait\s+(\d+)\s*(?:minutes?|mins?|m)/i
        minutes = $1.to_i
        return Time.current + minutes.minutes if minutes > 0
      end

      # Try "wait N hours" format
      if error_message =~ /wait\s+(\d+)\s*(?:hours?|hrs?|h)/i
        hours = $1.to_i
        return Time.current + hours.hours if hours > 0
      end

      # Try "in ~N min" format (Codex/ChatGPT Plus): "Try again in ~3682 min"
      if error_message =~ /in\s+~?(\d+)\s*min/i
        minutes = $1.to_i
        return Time.current + minutes.minutes if minutes > 0
      end

      # Try "usage limit" with minutes (ChatGPT Plus format)
      if error_message =~ /usage\s+limit.*?(\d+)\s*min/i
        minutes = $1.to_i
        return Time.current + minutes.minutes if minutes > 0
      end

      # Default: assume 1 hour if we can't parse
      if error_message =~ /rate\s*limit|usage\s*limit/i
        return Time.current + 1.hour
      end

      nil
    end
  end
end
