# frozen_string_literal: true

class SendPolicyController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  RULE_ACTIONS = %w[allow deny].freeze
  CHAT_TYPES = %w[direct group thread].freeze

  # GET /send-policy
  def show
    config_data = fetch_config
    @send_policy = extract_send_policy(config_data)
    @access_groups = extract_access_groups(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /send-policy
  def update
    patch = build_send_policy_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Send policy / access groups updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to send_policy_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("send_policy")
      redirect_to send_policy_path, notice: "Send policy & access groups updated."
    end
  rescue StandardError => e
    redirect_to send_policy_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("send_policy")
  end

  def extract_send_policy(config)
    return default_send_policy if config.nil? || config["error"].present? || config[:error].present?

    session = config.dig("session") || config.dig(:session) || {}
    sp = session.dig("sendPolicy") || session.dig(:send_policy) || {}

    {
      default_action: sp["default"] || "allow",
      rules: Array(sp["rules"]).map do |r|
        {
          action: r["action"] || "allow",
          channel: r["channel"],
          chat_type: r["chatType"],
          target: r["target"],
          description: r["description"] || ""
        }
      end
    }
  end

  def extract_access_groups(config)
    return {} if config.nil? || config["error"].present? || config[:error].present?

    session = config.dig("session") || config.dig(:session) || {}
    groups = session.dig("accessGroups") || session.dig(:access_groups) || {}

    result = {}
    groups.each do |name, cfg|
      next unless cfg.is_a?(Hash)
      result[name] = {
        commands: Array(cfg["commands"] || cfg[:commands]),
        members: Array(cfg["members"] || cfg[:members]),
        description: cfg["description"] || ""
      }
    end
    result
  end

  def default_send_policy
    { default_action: "allow", rules: [] }
  end

  def build_send_policy_patch
    sp = params.permit(:default_action, :group_name, :group_commands, :group_members)

    patch = { session: {} }

    if sp[:default_action].present? && RULE_ACTIONS.include?(sp[:default_action])
      patch[:session][:sendPolicy] = { default: sp[:default_action] }
    end

    # Update a single access group if provided
    if sp[:group_name].present?
      name = sp[:group_name].to_s.strip
      commands = sp[:group_commands].to_s.split(",").map(&:strip).reject(&:blank?)
      members = sp[:group_members].to_s.split(",").map(&:strip).reject(&:blank?)

      patch[:session][:accessGroups] = {
        name => { commands: commands, members: members }
      }
    end

    patch
  end
end
