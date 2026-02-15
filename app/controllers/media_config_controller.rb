# frozen_string_literal: true

class MediaConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /media-config
  def show
    config_data = fetch_config
    @media_config = extract_media_config(config_data)
    @error = config_data[:error] if config_data.is_a?(Hash) && config_data[:error]
  end

  # PATCH /media-config
  def update
    patch_body = build_patch_from_params

    result = gateway_client.config_patch(
      raw: patch_body.to_json,
      reason: "Media config updated via ClawTrol UI"
    )

    if result["error"].present?
      redirect_to media_config_path, alert: "Failed to update: #{result['error']}"
    else
      redirect_to media_config_path, notice: "Media configuration updated. Gateway will restart to apply changes."
    end
  rescue StandardError => e
    redirect_to media_config_path, alert: "Update failed: #{e.message}"
  end

  private

  def fetch_config
    Rails.cache.fetch("media_config/#{current_user.id}", expires_in: 30.seconds) do
      gateway_client.config_get
    end
  rescue StandardError => e
    { error: e.message }
  end

  def extract_media_config(config)
    return default_media_config if config.nil? || config[:error].present?

    tools = config.dig("tools") || config.dig(:tools) || {}
    media = tools.dig("media") || tools.dig(:media) || {}

    {
      audio: {
        enabled: media.dig("audio", "enabled") != false,
        provider: media.dig("audio", "provider") || "openai",
        model: media.dig("audio", "model") || "whisper-1",
        max_file_size_mb: media.dig("audio", "maxFileSizeMb") || 25,
        language: media.dig("audio", "language") || "auto"
      },
      video: {
        enabled: media.dig("video", "enabled") != false,
        provider: media.dig("video", "provider") || "google",
        model: media.dig("video", "model") || "gemini-2.0-flash",
        max_file_size_mb: media.dig("video", "maxFileSizeMb") || 100,
        extract_frames: media.dig("video", "extractFrames") != false
      },
      image: {
        enabled: media.dig("image", "enabled") != false,
        provider: media.dig("image", "provider") || "openai",
        model: media.dig("image", "model") || "gpt-4o"
      }
    }
  end

  def default_media_config
    {
      audio: { enabled: true, provider: "openai", model: "whisper-1", max_file_size_mb: 25, language: "auto" },
      video: { enabled: true, provider: "google", model: "gemini-2.0-flash", max_file_size_mb: 100, extract_frames: true },
      image: { enabled: true, provider: "openai", model: "gpt-4o" }
    }
  end

  def build_patch_from_params
    media_params = params.permit(
      audio: [:enabled, :provider, :model, :maxFileSizeMb, :language],
      video: [:enabled, :provider, :model, :maxFileSizeMb, :extractFrames],
      image: [:enabled, :provider, :model]
    )

    patch = { tools: { media: {} } }

    if media_params[:audio]
      audio = media_params[:audio].to_h
      audio["enabled"] = audio["enabled"] == "true" || audio["enabled"] == "1"
      audio["maxFileSizeMb"] = audio["maxFileSizeMb"].to_i if audio["maxFileSizeMb"]
      patch[:tools][:media][:audio] = audio
    end

    if media_params[:video]
      video = media_params[:video].to_h
      video["enabled"] = video["enabled"] == "true" || video["enabled"] == "1"
      video["maxFileSizeMb"] = video["maxFileSizeMb"].to_i if video["maxFileSizeMb"]
      video["extractFrames"] = video["extractFrames"] == "true" || video["extractFrames"] == "1"
      patch[:tools][:media][:video] = video
    end

    if media_params[:image]
      image = media_params[:image].to_h
      image["enabled"] = image["enabled"] == "true" || image["enabled"] == "1"
      patch[:tools][:media][:image] = image
    end

    patch
  end
end
