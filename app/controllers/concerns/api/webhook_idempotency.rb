# frozen_string_literal: true

module Api
  # Idempotency helper for webhook-authenticated endpoints.
  #
  # Wraps a controller action body. If the incoming request carries an
  # X-Hook-Event-Id header and a WebhookLog with the same (endpoint, event_id)
  # pair already exists, the cached response_body + status_code are replayed
  # without re-running the action. Otherwise the block is executed; after it
  # finishes the committed response body + status are logged for future replays.
  #
  # No-ops when the header is absent so legacy callers keep working.
  module WebhookIdempotency
    extend ActiveSupport::Concern

    private

    def idempotent_hook!
      event_id = request.headers["X-Hook-Event-Id"].to_s
      return yield if event_id.blank?

      endpoint = "#{controller_name}##{action_name}"

      existing = WebhookLog.find_by(endpoint: endpoint, event_id: event_id)
      if existing
        Rails.logger.info("[WebhookIdempotency] replay endpoint=#{endpoint} event_id=#{event_id}")
        cached_body = existing.response_body.presence || { ok: true, replay: true }
        render json: cached_body, status: existing.status_code || 200
        return
      end

      result = yield

      # Capture what the action actually rendered so we can replay it verbatim.
      response_hash = extract_response_hash(result)
      status_code = response.status
      return result unless response_hash

      begin
        WebhookLog.create!(
          direction: "incoming",
          event_type: endpoint,
          endpoint: endpoint,
          method: request.method,
          event_id: event_id,
          response_body: response_hash,
          status_code: status_code,
          success: status_code.to_i.between?(200, 299)
        )
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.info("[WebhookIdempotency] race on endpoint=#{endpoint} event_id=#{event_id}")
      rescue StandardError => e
        Rails.logger.warn("[WebhookIdempotency] failed to persist log: #{e.class}: #{e.message}")
      end

      result
    end

    def extract_response_hash(result)
      return result if result.is_a?(Hash)

      body = response.body.to_s
      return nil if body.blank?
      parsed = JSON.parse(body)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end
  end
end
