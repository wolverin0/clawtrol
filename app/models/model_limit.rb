# frozen_string_literal: true

# Tracks rate limits for AI models per user.
# Supports dynamic provider/model IDs (not limited to a static enum).
class ModelLimit < ApplicationRecord
  strict_loading :n_plus_one
  belongs_to :user, inverse_of: :model_limits

  validates :name, presence: true, length: { maximum: 120 }
  validates :name, uniqueness: { scope: :user_id }
  validates :resets_at, presence: true, if: -> { limited? }
  validates :error_message, length: { maximum: 1000 }, allow_nil: true

  scope :limited, -> { where(limited: true) }
  scope :available, -> { where(limited: false).or(where("resets_at <= ?", Time.current)) }
  scope :active_limits, -> { where(limited: true).where("resets_at > ?", Time.current) }

  MODEL_PRIORITY = %w[codex sonnet gemini3 gemini3_flash glm opus].freeze

  def active_limit?
    limited? && resets_at.present? && resets_at > Time.current
  end

  def clear!
    update!(limited: false, resets_at: nil, error_message: nil)
  end

  def set_limit!(error_message:, resets_at: nil)
    update!(
      limited: true,
      resets_at: resets_at,
      error_message: error_message,
      last_error_at: Time.current
    )
  end

  def time_until_reset
    return nil unless resets_at.present? && resets_at > Time.current

    seconds = (resets_at - Time.current).to_i
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m"
    elsif seconds < 86_400
      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    else
      "#{seconds / 86_400}d #{(seconds % 86_400) / 3600}h"
    end
  end

  class << self
    def for_model(user, name)
      find_or_create_by(user: user, name: name)
    end

    def model_available?(user, name)
      limit = find_by(user: user, name: name)
      return true if limit.nil?

      !limit.active_limit?
    end

    # Returns [selected_model, fallback_note]
    # Forward-cost guard: never fallback to Opus unless requested model was Opus.
    def best_available_model(user, requested_model = nil)
      requested = requested_model.to_s.presence
      models_to_try = []
      models_to_try << requested if requested

      chain = fallback_chain_for(user, requested)
      models_to_try.concat(chain)
      models_to_try.concat(MODEL_PRIORITY) if requested.blank?
      models_to_try = models_to_try.compact.map(&:to_s).map(&:strip).reject(&:blank?).uniq

      models_to_try.each_with_index do |model, idx|
        next if requested.present? && forbidden_forward_fallback?(requested, model)

        if model_available?(user, model)
          note = nil
          if requested.present? && model != requested
            original_limit = find_by(user: user, name: requested)
            reset_info = original_limit&.resets_at&.strftime("%b %d %H:%M") || "unknown"
            note = "⚠️ #{requested} rate-limited (resets #{reset_info}), using #{model}"
          end
          return [model, note]
        end
      end

      # Last resort: return requested or first chain entry even if limited.
      fallback = requested || models_to_try.first || MODEL_PRIORITY.first
      [fallback, "⚠️ All fallback models are currently limited, trying #{fallback}"]
    end

    def record_limit!(user, name, error_message)
      limit = for_model(user, name)
      resets_at = parse_reset_time(error_message)
      limit.set_limit!(error_message: error_message, resets_at: resets_at)
      limit
    end

    def clear_expired_limits!
      where(limited: true)
        .where("resets_at IS NOT NULL AND resets_at <= ?", Time.current)
        .update_all(limited: false)
    end

    private

    def fallback_chain_for(user, requested)
      configured = parse_fallback_chain(user&.fallback_model_chain)
      return configured if configured.any?

      default = case requested.to_s
      when "glm"
        %w[gemini3_flash gemini3 codex sonnet]
      when "gemini", "gemini3"
        %w[gemini3_flash glm codex sonnet]
      when "flash", "gemini3_flash"
        %w[glm gemini3 codex sonnet]
      when "codex"
        %w[sonnet gemini3 gemini3_flash glm]
      when "sonnet"
        %w[codex gemini3 gemini3_flash glm]
      when "opus"
        %w[codex sonnet gemini3 gemini3_flash glm]
      else
        MODEL_PRIORITY
      end

      default
    end

    def parse_fallback_chain(raw)
      return [] if raw.to_s.strip.blank?

      raw.to_s.split(/[\n,>]+/).map(&:strip).reject(&:blank?)
    end

    def forbidden_forward_fallback?(requested, candidate)
      candidate == "opus" && requested != "opus"
    end

    def parse_reset_time(error_message)
      return nil if error_message.blank?

      if error_message =~ /resets?\s+at\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[Z\+\-\d:]*)/i
        return Time.parse($1) rescue nil
      end

      if error_message =~ /try\s+again\s+at\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})/i
        return Time.parse($1) rescue nil
      end

      if error_message =~ /retry\s+after\s+(\d+)\s*(?:seconds?|secs?|s)?/i
        seconds = $1.to_i
        return Time.current + seconds.seconds if seconds > 0
      end

      if error_message =~ /wait\s+(\d+)\s*(?:minutes?|mins?|m)/i
        minutes = $1.to_i
        return Time.current + minutes.minutes if minutes > 0
      end

      if error_message =~ /wait\s+(\d+)\s*(?:hours?|hrs?|h)/i
        hours = $1.to_i
        return Time.current + hours.hours if hours > 0
      end

      if error_message =~ /in\s+~?(\d+)\s*min/i
        minutes = $1.to_i
        return Time.current + minutes.minutes if minutes > 0
      end

      if error_message =~ /usage\s+limit.*?(\d+)\s*min/i
        minutes = $1.to_i
        return Time.current + minutes.minutes if minutes > 0
      end

      return Time.current + 1.hour if error_message =~ /rate\s*limit|usage\s*limit/i

      nil
    end
  end
end
