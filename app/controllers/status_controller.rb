# frozen_string_literal: true

# Public (no auth) status endpoint for monitoring.
# Exposes minimal health info — no sensitive data.
class StatusController < ApplicationController
  # Skip authentication for the public status page.
  allow_unauthenticated_access

  # Rate limit to prevent abuse (60 requests per minute per IP)
  rate_limit to: 60, within: 1.minute, only: :show, with: -> {
    respond_to do |format|
      format.json { render json: { error: "Rate limit exceeded. Try again later." }, status: :too_many_requests }
      format.html { render plain: "Rate limit exceeded. Try again later.", status: :too_many_requests }
      format.any { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }
    end
  }

  # GET /status
  # Returns JSON or HTML depending on Accept header.
  def show
    @status = build_status

    # Cache for 15 seconds on CDN/proxies
    expires_in 15.seconds, public: true

    respond_to do |format|
      format.json { render json: @status }
      format.html # renders status/show.html.erb
      format.any { render json: @status }
    end
  end

  private

  def build_status
    gateway_health = fetch_gateway_health
    is_up = gateway_health && gateway_health["status"]&.match?(/ok|healthy|running/)

    {
      clawdeck: "ok",
      clawdeck_version: clawdeck_version,
      timestamp: Time.zone.now.iso8601,
      gateway: {
        status: is_up ? "online" : "offline",
        version: gateway_health&.dig("version"),
        active_sessions: gateway_health&.dig("activeSessions")
      },
      channels: fetch_channel_summary(gateway_health),
      uptime: process_uptime
    }
  end

  def fetch_gateway_health
    # Use the first user with gateway configured, or return nil.
    # Public status page doesn't leak user info — only gateway status.
    user = User.find_by("openclaw_gateway_url IS NOT NULL AND openclaw_gateway_url != ''")
    return nil unless user

    Rails.cache.fetch("public/status/health", expires_in: 30.seconds) do
      client = OpenclawGatewayClient.new(user)
      client.health
    end
  rescue StandardError
    nil
  end

  def fetch_channel_summary(health_data)
    return {} unless health_data

    # Extract channel info from health if available
    channels = health_data["channels"] || {}
    channels.transform_values do |v|
      v.is_a?(Hash) ? (v["connected"] || v["status"] || "unknown") : v
    end
  rescue StandardError
    {}
  end

  def clawdeck_version
    # Read from a VERSION file or git
    @clawdeck_version ||= begin
      version_file = Rails.root.join("VERSION")
      if version_file.exist?
        version_file.read.strip
      else
        `git -C #{Rails.root} describe --tags --always 2>/dev/null`.strip.presence || "dev"
      end
    end
  end

  def process_uptime
    # Linux: read from /proc/uptime for system uptime
    if File.exist?("/proc/uptime")
      seconds = File.read("/proc/uptime").split.first.to_f
      hours = (seconds / 3600).floor
      "#{hours}h"
    else
      "unknown"
    end
  rescue StandardError
    "unknown"
  end
end
