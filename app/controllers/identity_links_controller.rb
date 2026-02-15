# frozen_string_literal: true

# Session Identity Links UI: manage cross-channel identity mappings.
#
# OpenClaw supports `session.identityLinks` to map the same person across channels
# (e.g., telegram:123 = discord:456). This controller reads/writes those mappings
# via gateway config.
class IdentityLinksController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /identity_links
  def index
    @config_data = gateway_client.config_get
    @links = extract_identity_links(@config_data)
    @channels_status = gateway_client.channels_status
    @available_channels = extract_available_channels(@channels_status)
  end

  # POST /identity_links/save
  def save
    links_json = params[:links_json].to_s.strip
    if links_json.blank?
      render json: { success: false, error: "Links JSON required" }, status: :unprocessable_entity
      return
    end

    if links_json.bytesize > 64.kilobytes
      render json: { success: false, error: "Links too large (max 64KB)" }, status: :unprocessable_entity
      return
    end

    begin
      parsed = JSON.parse(links_json)
      unless parsed.is_a?(Array)
        render json: { success: false, error: "Links must be a JSON array" }, status: :unprocessable_entity
        return
      end

      # Validate structure
      parsed.each_with_index do |link, i|
        unless link.is_a?(Array) && link.size >= 2 && link.all? { |id| id.is_a?(String) && id.include?(":") }
          render json: { success: false, error: "Link ##{i + 1} must be an array of 'channel:id' strings (min 2)" }, status: :unprocessable_entity
          return
        end
      end
    rescue JSON::ParserError => e
      render json: { success: false, error: "Invalid JSON: #{e.message}" }, status: :unprocessable_entity
      return
    end

    patch = { "session" => { "identityLinks" => parsed } }
    result = gateway_client.config_patch(raw: patch.to_json, reason: "Identity links updated from ClawTrol")

    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Identity links saved. Gateway restarting..." }
    end
  end

  private

  def extract_identity_links(config)
    return [] unless config.is_a?(Hash) && config["error"].blank?

    raw = config.dig("config") || config
    session = raw["session"]
    return [] unless session.is_a?(Hash)

    links = session["identityLinks"] || session["identity_links"] || []
    return [] unless links.is_a?(Array)

    links.map.with_index do |link_group, i|
      identities = Array(link_group).map do |identity|
        parts = identity.to_s.split(":", 2)
        { channel: parts[0], id: parts[1] || parts[0], raw: identity.to_s }
      end
      { index: i, identities: identities }
    end
  end

  def extract_available_channels(channels_data)
    return %w[telegram discord whatsapp signal slack] unless channels_data.is_a?(Hash)

    channels = channels_data["channels"] || []
    names = Array(channels).filter_map { |c| c.is_a?(Hash) ? c["name"] || c["type"] : c.to_s }
    names.any? ? names : %w[telegram discord whatsapp signal slack]
  end
end
