# frozen_string_literal: true

class IdentityConfigController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /identity-config
  def show
    config_data = fetch_config
    @identity = extract_identity(config_data)
    @messages = extract_messages(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /identity-config
  def update
    patch = build_identity_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Identity & branding updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to identity_config_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("identity_cfg")
      redirect_to identity_config_path, notice: "Identity & branding updated."
    end
  rescue StandardError => e
    redirect_to identity_config_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("identity_cfg")
  end

  def extract_identity(config)
    return default_identity if config.nil? || config["error"].present? || config[:error].present?

    id = config.dig("identity") || config.dig(:identity) || {}

    {
      name: id["name"] || "",
      theme: id["theme"] || "",
      emoji: id["emoji"] || "",
      avatar: id["avatar"] || ""
    }
  end

  def extract_messages(config)
    return default_messages if config.nil? || config["error"].present? || config[:error].present?

    msg = config.dig("messages") || config.dig(:messages) || {}

    {
      prefix: msg["prefix"] || "",
      response_prefix: msg["responsePrefix"] || "",
      ack_reaction: msg["ackReaction"] || "",
      ack_reaction_scope: msg["ackReactionScope"] || "all"
    }
  end

  def default_identity
    { name: "", theme: "", emoji: "", avatar: "" }
  end

  def default_messages
    { prefix: "", response_prefix: "", ack_reaction: "", ack_reaction_scope: "all" }
  end

  def build_identity_patch
    ip = params.permit(:name, :theme, :emoji, :avatar,
                       :prefix, :response_prefix, :ack_reaction, :ack_reaction_scope)

    patch = {}

    identity_patch = {}
    identity_patch[:name] = ip[:name] if ip[:name].present?
    identity_patch[:theme] = ip[:theme] if ip[:theme].present?
    identity_patch[:emoji] = ip[:emoji] if ip[:emoji].present?
    identity_patch[:avatar] = ip[:avatar] if ip[:avatar].present?
    patch[:identity] = identity_patch if identity_patch.any?

    messages_patch = {}
    messages_patch[:prefix] = ip[:prefix] if ip.key?(:prefix)
    messages_patch[:responsePrefix] = ip[:response_prefix] if ip.key?(:response_prefix)
    messages_patch[:ackReaction] = ip[:ack_reaction] if ip.key?(:ack_reaction)
    messages_patch[:ackReactionScope] = ip[:ack_reaction_scope] if ip[:ack_reaction_scope].present?
    patch[:messages] = messages_patch if messages_patch.any?

    patch
  end
end
