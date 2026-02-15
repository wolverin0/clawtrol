# frozen_string_literal: true

# Block Streaming Config UI: configure OpenClaw's chunked message delivery.
#
# OpenClaw's `blockStreaming` controls how agent responses are chunked before
# sending to messaging channels. Settings include chunk sizes, coalesce delays,
# and per-channel overrides.
class BlockStreamingController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /streaming
  def show
    @config_data = gateway_client.config_get
    @channels_data = gateway_client.channels_status

    @streaming_config = extract_streaming_config(@config_data)
    @channels = extract_channels(@channels_data)
    @preview = generate_preview(@streaming_config)
  end

  # PATCH /streaming/update
  def update
    config_json = params[:streaming_config].to_s.strip
    if config_json.blank?
      render json: { success: false, error: "Config required" }, status: :unprocessable_entity
      return
    end

    if config_json.bytesize > 32.kilobytes
      render json: { success: false, error: "Config too large" }, status: :unprocessable_entity
      return
    end

    begin
      parsed = JSON.parse(config_json)
    rescue JSON::ParserError => e
      render json: { success: false, error: "Invalid JSON: #{e.message}" }, status: :unprocessable_entity
      return
    end

    patch = { "blockStreaming" => parsed }
    result = gateway_client.config_patch(raw: patch.to_json, reason: "Block streaming config updated from ClawTrol")

    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Streaming config saved. Gateway restarting..." }
    end
  end

  private

  def extract_streaming_config(config)
    return default_streaming_config unless config.is_a?(Hash) && config["error"].blank?

    raw = config.dig("config") || config
    bs = raw["blockStreaming"]
    return default_streaming_config unless bs.is_a?(Hash)

    {
      enabled: bs.fetch("enabled", true),
      chunk_size: bs["chunkSize"] || bs["maxChunkChars"] || 2000,
      coalesce_ms: bs["coalesceMs"] || bs["coalesceDelayMs"] || 500,
      min_chunk: bs["minChunkChars"] || 100,
      split_on: bs["splitOn"] || "paragraph",
      per_channel: bs["perChannel"] || bs["channels"] || {},
      raw: bs
    }
  end

  def default_streaming_config
    {
      enabled: true,
      chunk_size: 2000,
      coalesce_ms: 500,
      min_chunk: 100,
      split_on: "paragraph",
      per_channel: {},
      raw: {}
    }
  end

  def extract_channels(channels_data)
    return [] unless channels_data.is_a?(Hash) && channels_data["error"].blank?

    Array(channels_data["channels"]).map do |c|
      c["name"] || c["type"]
    end.compact
  end

  def generate_preview(config)
    chunk = config[:chunk_size]
    coalesce = config[:coalesce_ms]

    sample_text = "This is a sample agent response. " * 20
    chunks = []

    if config[:split_on] == "paragraph"
      # Paragraph splitting simulation
      while sample_text.length > 0
        chunk_text = sample_text.first(chunk)
        chunks << chunk_text
        sample_text = sample_text[chunk..]
        break if sample_text.nil? || sample_text.empty?
      end
    else
      chunks = sample_text.scan(/.{1,#{chunk}}/)
    end

    {
      total_chars: (sample_text || "").length + chunks.sum(&:length),
      chunk_count: chunks.size,
      estimated_delivery_ms: chunks.size * coalesce,
      chunks: chunks.first(3) # Preview first 3 chunks
    }
  end
end
