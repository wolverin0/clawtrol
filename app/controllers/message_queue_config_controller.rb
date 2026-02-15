# frozen_string_literal: true

class MessageQueueConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  QUEUE_MODES = %w[collect immediate passthrough].freeze
  DROP_STRATEGIES = %w[oldest newest none].freeze

  # GET /message-queue
  def show
    config_data = fetch_config
    @queue_config = extract_queue_config(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /message-queue
  def update
    patch = build_queue_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Message queue config updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to message_queue_config_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("queue_config")
      redirect_to message_queue_config_path, notice: "Message queue configuration updated."
    end
  rescue StandardError => e
    redirect_to message_queue_config_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("queue_config")
  end

  def extract_queue_config(config)
    return default_queue_config if config.nil? || config["error"].present? || config[:error].present?

    routing = config.dig("routing") || config.dig(:routing) || {}
    queue = routing.dig("queue") || routing.dig(:queue) || {}

    {
      mode: queue["mode"] || queue[:mode] || "collect",
      debounce_ms: queue["debounceMs"] || queue[:debounce_ms] || 2000,
      cap: queue["cap"] || queue[:cap] || 10,
      drop_strategy: queue["dropStrategy"] || queue[:drop_strategy] || "oldest",
      per_channel: extract_per_channel_queue(queue)
    }
  end

  def extract_per_channel_queue(queue)
    overrides = queue["channels"] || queue[:channels] || {}
    result = {}
    overrides.each do |channel, cfg|
      next unless cfg.is_a?(Hash)
      result[channel] = {
        mode: cfg["mode"],
        debounce_ms: cfg["debounceMs"],
        cap: cfg["cap"],
        drop_strategy: cfg["dropStrategy"]
      }.compact
    end
    result
  end

  def default_queue_config
    {
      mode: "collect",
      debounce_ms: 2000,
      cap: 10,
      drop_strategy: "oldest",
      per_channel: {}
    }
  end

  def build_queue_patch
    qp = params.permit(:mode, :debounce_ms, :cap, :drop_strategy)
    queue_patch = {}

    if qp[:mode].present? && QUEUE_MODES.include?(qp[:mode])
      queue_patch[:mode] = qp[:mode]
    end

    if qp[:debounce_ms].present?
      val = qp[:debounce_ms].to_i
      queue_patch[:debounceMs] = val.clamp(100, 30_000)
    end

    if qp[:cap].present?
      val = qp[:cap].to_i
      queue_patch[:cap] = val.clamp(1, 100)
    end

    if qp[:drop_strategy].present? && DROP_STRATEGIES.include?(qp[:drop_strategy])
      queue_patch[:dropStrategy] = qp[:drop_strategy]
    end

    { routing: { queue: queue_patch } }
  end
end
