# frozen_string_literal: true

class ChannelAccountsController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  SUPPORTED_CHANNELS = %w[telegram whatsapp discord signal slack irc googlechat imessage].freeze

  # GET /channel-accounts
  def show
    config_data = fetch_config
    @channels = extract_channel_accounts(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /channel-accounts
  def update
    channel = params[:channel].to_s
    account_id = params[:account_id].to_s.strip

    unless SUPPORTED_CHANNELS.include?(channel)
      redirect_to channel_accounts_path, alert: "Unsupported channel: #{channel}"
      return
    end

    patch_body = build_account_patch(channel, account_id, account_params)

    result = gateway_client.config_patch(
      raw: patch_body.to_json,
      reason: "Channel account #{account_id} updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to channel_accounts_path, alert: "Failed: #{result['error']}"
    else
      redirect_to channel_accounts_path, notice: "Account #{account_id} on #{channel} updated."
    end
  rescue StandardError => e
    redirect_to channel_accounts_path, alert: "Error: #{e.message}"
  end

  private

  def account_params
    params.permit(:dm_policy, :send_read_receipts, :allow_from, :agent_binding)
  end

  def fetch_config
    cached_config_get("channel_accounts")
  end

  def extract_channel_accounts(config)
    return [] if config.nil? || config["error"].present? || config[:error].present?

    channels_cfg = config.dig("channels") || config.dig(:channels) || {}
    result = []

    SUPPORTED_CHANNELS.each do |ch|
      ch_config = channels_cfg[ch]
      next unless ch_config.is_a?(Hash)

      accounts = ch_config["accounts"] || ch_config[:accounts]

      if accounts.is_a?(Array) && accounts.any?
        accounts.each do |acct|
          result << build_account_entry(ch, acct)
        end
      elsif accounts.is_a?(Hash)
        accounts.each do |acct_id, acct_cfg|
          result << build_account_entry(ch, acct_cfg.merge("id" => acct_id))
        end
      else
        # Single account (the channel config itself)
        result << build_account_entry(ch, ch_config.merge("id" => "default"))
      end
    end

    result
  end

  def build_account_entry(channel, acct)
    {
      channel: channel,
      id: acct["id"] || acct[:id] || "default",
      name: acct["name"] || acct[:name] || acct["id"] || channel.capitalize,
      dm_policy: acct.dig("dm", "policy") || acct.dig("dmPolicy") || "open",
      allow_from: acct["allowFrom"] || acct[:allow_from] || [],
      send_read_receipts: acct["sendReadReceipts"] != false,
      agent_binding: acct["agentBinding"] || acct[:agent_binding],
      status: acct["status"] || "configured",
      icon: channel_icon(channel)
    }
  end

  def build_account_patch(channel, account_id, params)
    account_patch = {}
    account_patch["dmPolicy"] = params[:dm_policy] if params[:dm_policy].present?
    account_patch["sendReadReceipts"] = params[:send_read_receipts] == "true" if params.key?(:send_read_receipts)
    account_patch["allowFrom"] = params[:allow_from].split(",").map(&:strip) if params[:allow_from].present?
    account_patch["agentBinding"] = params[:agent_binding] if params[:agent_binding].present?

    { channels: { channel => { accounts: { account_id => account_patch } } } }
  end

  def channel_icon(channel)
    {
      "telegram" => "✈️",
      "whatsapp" => "💬",
      "discord" => "🎮",
      "signal" => "🔒",
      "slack" => "💼",
      "irc" => "📡",
      "googlechat" => "🔵",
      "imessage" => "🍎"
    }[channel] || "📱"
  end
end
