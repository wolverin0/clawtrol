# frozen_string_literal: true

class DmPolicyController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  DM_POLICIES = %w[open pairing allowlist disabled].freeze
  GROUP_POLICIES = %w[open allowlist disabled].freeze

  # GET /dm-policy
  def show
    config_data = fetch_config
    @dm_config = extract_dm_config(config_data)
    @pairing_queue = extract_pairing_queue(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /dm-policy
  def update
    patch = build_dm_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "DM/group policy updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to dm_policy_path, alert: "Failed: #{result['error']}"
    else
      Rails.cache.delete("dm_policy/#{current_user.id}")
      redirect_to dm_policy_path, notice: "DM/Group policies updated."
    end
  rescue StandardError => e
    redirect_to dm_policy_path, alert: "Error: #{e.message}"
  end

  # POST /dm-policy/approve-pairing
  def approve_pairing
    pairing_id = params[:pairing_id].to_s.strip
    if pairing_id.blank?
      render json: { error: "Pairing ID required" }, status: :unprocessable_entity
      return
    end

    # Approve via gateway RPC
    result = gateway_client.config_patch(
      raw: { session: { approvedPairings: [pairing_id] } }.to_json,
      reason: "Pairing #{pairing_id} approved via ClawTrol"
    )

    if result["error"].present?
      render json: { error: result["error"] }, status: :unprocessable_entity
    else
      render json: { success: true, pairing_id: pairing_id }
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  # POST /dm-policy/reject-pairing
  def reject_pairing
    pairing_id = params[:pairing_id].to_s.strip
    if pairing_id.blank?
      render json: { error: "Pairing ID required" }, status: :unprocessable_entity
      return
    end

    result = gateway_client.config_patch(
      raw: { session: { rejectedPairings: [pairing_id] } }.to_json,
      reason: "Pairing #{pairing_id} rejected via ClawTrol"
    )

    if result["error"].present?
      render json: { error: result["error"] }, status: :unprocessable_entity
    else
      render json: { success: true, pairing_id: pairing_id }
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def fetch_config
    Rails.cache.fetch("dm_policy/#{current_user.id}", expires_in: 30.seconds) do
      gateway_client.config_get
    end
  rescue StandardError => e
    { error: e.message }
  end

  def extract_dm_config(config)
    return default_dm_config if config.nil? || config["error"].present? || config[:error].present?

    session = config.dig("session") || config.dig(:session) || {}
    channels = config.dig("channels") || config.dig(:channels) || {}

    {
      global_dm_policy: session.dig("dm", "policy") || session.dig("dmPolicy") || "open",
      global_group_policy: session.dig("group", "policy") || session.dig("groupPolicy") || "open",
      allow_from: session.dig("dm", "allowFrom") || session["allowFrom"] || [],
      group_allow_from: session.dig("group", "allowFrom") || [],
      pairing_code: session.dig("dm", "pairingCode") || session["pairingCode"],
      per_channel: extract_per_channel_policies(channels)
    }
  end

  def extract_per_channel_policies(channels)
    result = {}
    channels.each do |name, cfg|
      next unless cfg.is_a?(Hash)
      result[name] = {
        dm_policy: cfg.dig("dm", "policy") || cfg["dmPolicy"],
        group_policy: cfg.dig("group", "policy") || cfg["groupPolicy"],
        allow_from: cfg.dig("dm", "allowFrom") || cfg["allowFrom"] || []
      }
    end
    result
  end

  def extract_pairing_queue(config)
    return [] if config.nil? || config["error"].present? || config[:error].present?

    session = config.dig("session") || config.dig(:session) || {}
    pending = session.dig("pendingPairings") || session.dig("dm", "pendingPairings") || []

    pending.map do |p|
      if p.is_a?(Hash)
        {
          id: p["id"] || p["code"],
          channel: p["channel"] || "unknown",
          sender: p["sender"] || p["from"] || "unknown",
          requested_at: p["requestedAt"] || p["timestamp"],
          status: "pending"
        }
      else
        { id: p.to_s, channel: "unknown", sender: "unknown", requested_at: nil, status: "pending" }
      end
    end
  end

  def default_dm_config
    {
      global_dm_policy: "open",
      global_group_policy: "open",
      allow_from: [],
      group_allow_from: [],
      pairing_code: nil,
      per_channel: {}
    }
  end

  def build_dm_patch
    dm_params = params.permit(:dm_policy, :group_policy, :allow_from, :group_allow_from, :pairing_code)

    session_patch = { dm: {}, group: {} }

    if dm_params[:dm_policy].present? && DM_POLICIES.include?(dm_params[:dm_policy])
      session_patch[:dm][:policy] = dm_params[:dm_policy]
    end

    if dm_params[:group_policy].present? && GROUP_POLICIES.include?(dm_params[:group_policy])
      session_patch[:group][:policy] = dm_params[:group_policy]
    end

    if dm_params[:allow_from].present?
      session_patch[:dm][:allowFrom] = dm_params[:allow_from].split(",").map(&:strip).reject(&:blank?)
    end

    if dm_params[:group_allow_from].present?
      session_patch[:group][:allowFrom] = dm_params[:group_allow_from].split(",").map(&:strip).reject(&:blank?)
    end

    if dm_params[:pairing_code].present?
      session_patch[:dm][:pairingCode] = dm_params[:pairing_code]
    end

    { session: session_patch }
  end
end
