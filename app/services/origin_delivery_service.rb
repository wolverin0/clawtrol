# frozen_string_literal: true

# Delivers task outcomes back to the origin session when available.
class OriginDeliveryService
  def initialize(task, task_run:, logger: Rails.logger)
    @task = task
    @task_run = task_run
    @logger = logger
  end

  def deliver_outcome!
    deliver_to_session if @task.origin_session_key.present?
  end

  private

  def deliver_to_session
    return unless openclaw_configured?

    message = build_message
    OpenclawGatewayClient.new(@task.user).sessions_send(@task.origin_session_key, message)
  rescue StandardError => e
    @logger.warn("[OriginDelivery] session delivery failed task_id=#{@task.id} err=#{e.class}: #{e.message}")
  end

  def openclaw_configured?
    user = @task.user
    hooks_token = user.respond_to?(:openclaw_hooks_token) ? user.openclaw_hooks_token : nil
    return false unless user&.openclaw_gateway_url.present?
    return false if user.openclaw_gateway_url.to_s.match?(/example/i)

    hooks_token.present? || user.openclaw_gateway_token.present?
  end

  def build_message
    payload = @task_run.raw_payload.with_indifferent_access
    lines = []
    lines << "Outcome for Task ##{@task.id}: #{@task.name}"
    lines << "Summary: #{@task_run.summary}" if @task_run.summary.present?

    changes = Array(payload[:changes]).map(&:to_s).reject(&:blank?)
    if changes.any?
      lines << "Changes:"
      lines.concat(changes.map { |c| "- #{c}" })
    end

    validation = payload[:validation]
    if validation.present?
      lines << "Validation:"
      if validation.is_a?(Hash)
        validation.each { |key, value| lines << "- #{key}: #{value}" }
      else
        lines << validation.to_s
      end
    end

    follow_up = Array(payload[:follow_up]).map(&:to_s).reject(&:blank?)
    if follow_up.any?
      lines << "Follow-up:"
      lines.concat(follow_up.map { |item| "- #{item}" })
    end

    lines << "Recommended action: #{@task_run.recommended_action}"
    lines << "Needs follow-up: #{@task_run.needs_follow_up? ? 'YES' : 'NO'}"
    lines.join("\n")
  end
end
