# frozen_string_literal: true

class WebhookLog < ApplicationRecord
  belongs_to :user, inverse_of: :webhook_logs
  belongs_to :task, optional: true

  DIRECTIONS = %w[incoming outgoing].freeze

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :event_type, presence: true
  validates :endpoint, presence: true, length: { maximum: 2000 }
  validates :method, presence: true
  validates :error_message, length: { maximum: 5000 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :incoming, -> { where(direction: "incoming") }
  scope :failed, -> { where(success: false) }

  MAX_BODY_BYTES = 50_000

  def self.record!(user:, direction:, event_type:, endpoint:, method: "POST", task: nil, status_code: nil,
                   duration_ms: nil, request_headers: nil, request_body: nil, response_body: nil, error: nil)
    sanitized_headers = sanitize_headers(request_headers)
    safe_request_body = truncate_body(request_body)
    safe_response_body = truncate_body(response_body)

    attrs = {
      user: user,
      task: task,
      direction: direction,
      event_type: event_type,
      endpoint: endpoint,
      method: method,
      status_code: status_code,
      duration_ms: duration_ms,
      request_headers: sanitized_headers || {},
      request_body: safe_request_body || {},
      response_body: safe_response_body || {},
      error_message: error.presence,
      success: compute_success(status_code, error)
    }

    create!(attrs)
  rescue StandardError => e
    Rails.logger.warn("[WebhookLog] record! failed: #{e.class}: #{e.message}")
    nil
  end

  def self.trim!(user:, keep: 200)
    keep = keep.to_i
    keep = 0 if keep.negative?

    ids = where(user_id: user.id).order(created_at: :desc).offset(keep).pluck(:id)
    where(id: ids).delete_all if ids.any?
  end

  def self.compute_success(status_code, error)
    return false if error.present?
    return false if status_code.present? && status_code.to_i >= 400

    status_code.present? ? status_code.to_i.between?(200, 299) : true
  end

  def self.sanitize_headers(headers)
    return {} if headers.blank?

    sanitized = headers.to_h.deep_dup
    %w[Authorization X-Hook-Token].each do |key|
      if sanitized.key?(key)
        sanitized[key] = "[REDACTED]"
      end
    end
    sanitized
  rescue StandardError
    {}
  end

  def self.truncate_body(body)
    return {} if body.blank?

    json = body.is_a?(String) ? body : body.to_json
    size = json.bytesize

    return body if size <= MAX_BODY_BYTES

    {
      "_truncated" => true,
      "_size" => size,
      "_preview" => json.byteslice(0, MAX_BODY_BYTES)
    }
  rescue StandardError
    { "_truncated" => true, "_size" => 0 }
  end
end
