# frozen_string_literal: true

class WebhookLog < ApplicationRecord
  # Enforce eager loading to prevent N+1 queries in views
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :webhook_logs
  belongs_to :task, optional: true

  DIRECTIONS = %w[incoming outgoing].freeze
  SENSITIVE_HEADERS = %w[Authorization X-Hook-Token X-Api-Key].freeze
  MAX_BODY_SIZE = 50_000 # characters

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :event_type, presence: true
  validates :endpoint, presence: true, length: { maximum: 2000 }
  validates :method, presence: true
  validates :error_message, length: { maximum: 5000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :failed, -> { where(success: false) }

  # Record a webhook log entry. Never raises on failure (fire-and-forget).
  #
  # @param user [User] the user context
  # @param direction [String] "incoming" or "outgoing"
  # @param event_type [String] e.g. "agent_complete", "wake"
  # @param endpoint [String] URL or path
  # @param status_code [Integer, nil] HTTP status code
  # @param error [String, nil] error message if the call failed
  # @param request_headers [Hash] headers (sensitive values will be redacted)
  # @param request_body [Hash] request payload (truncated if too large)
  # @param response_body [Hash] response payload
  # @param duration_ms [Integer, nil] request duration
  # @return [WebhookLog, nil] the created log or nil on error
  def self.record!(user:, direction:, event_type:, endpoint:, status_code: nil, error: nil,
                   request_headers: {}, request_body: {}, response_body: {}, duration_ms: nil, task: nil)
    # Determine success
    success = if status_code.present?
      status_code.to_i.between?(200, 299)
    else
      error.blank?
    end

    # Sanitize sensitive headers
    sanitized_headers = sanitize_headers(request_headers)

    # Truncate oversized bodies
    sanitized_request_body = truncate_body(request_body)
    sanitized_response_body = truncate_body(response_body)

    create!(
      user: user,
      task: task,
      direction: direction,
      event_type: event_type,
      endpoint: endpoint.to_s.truncate(2000),
      method: "POST",
      status_code: status_code,
      success: success,
      error_message: error&.to_s&.truncate(5000),
      request_headers: sanitized_headers,
      request_body: sanitized_request_body,
      response_body: sanitized_response_body,
      duration_ms: duration_ms
    )
  rescue StandardError => e
    Rails.logger.warn("[WebhookLog] record! failed: #{e.class}: #{e.message}")
    nil
  end

  # Trim old logs, keeping only the most recent N per user.
  #
  # @param user [User] the user to trim logs for
  # @param keep [Integer] number of recent logs to keep
  def self.trim!(user:, keep: 1000)
    cutoff_id = where(user: user)
      .order(created_at: :desc)
      .offset(keep)
      .limit(1)
      .pick(:id)

    return unless cutoff_id
    where(user: user).where("id <= ?", cutoff_id).delete_all
  end

  private_class_method def self.sanitize_headers(headers)
    return {} unless headers.is_a?(Hash)

    headers.each_with_object({}) do |(key, value), result|
      result[key] = SENSITIVE_HEADERS.any? { |s| key.to_s.casecmp?(s) } ? "[REDACTED]" : value
    end
  end

  private_class_method def self.truncate_body(body)
    return {} unless body.is_a?(Hash)

    json_str = body.to_json
    if json_str.length > MAX_BODY_SIZE
      { "_truncated" => true, "_size" => json_str.length, "_preview" => json_str[0, 500] }
    else
      body
    end
  end
end
