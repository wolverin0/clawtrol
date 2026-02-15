# frozen_string_literal: true

class CliBackendsController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /cli-backends
  def index
    config_data = fetch_config
    @backends = extract_backends(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /cli-backends
  def update
    backend_id = params[:backend_id].to_s.strip
    if backend_id.blank?
      redirect_to cli_backends_path, alert: "Backend ID required"
      return
    end

    patch = build_backend_patch(backend_id)

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "CLI backend #{backend_id} updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to cli_backends_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("cli_backends")
      redirect_to cli_backends_path, notice: "Backend '#{backend_id}' updated."
    end
  rescue StandardError => e
    redirect_to cli_backends_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("cli_backends")
  end

  def extract_backends(config)
    return [] if config.nil? || config["error"].present? || config[:error].present?

    backends_cfg = config.dig("cliBackends") || config.dig(:cli_backends) || {}
    result = []

    backends_cfg.each do |id, cfg|
      next unless cfg.is_a?(Hash)
      result << {
        id: id,
        command: cfg["command"] || cfg[:command] || "",
        args: Array(cfg["args"] || cfg[:args]),
        model_arg: cfg["modelArg"] || cfg[:model_arg] || "--model",
        session_arg: cfg["sessionArg"] || cfg[:session_arg] || "--session",
        image_arg: cfg["imageArg"] || cfg[:image_arg],
        enabled: cfg["enabled"] != false,
        fallback_priority: cfg["fallbackPriority"] || cfg[:fallback_priority] || 0,
        description: cfg["description"] || ""
      }
    end

    result.sort_by { |b| b[:fallback_priority] }
  end

  def build_backend_patch(backend_id)
    bp = params.permit(:command, :model_arg, :session_arg, :image_arg, :enabled, :fallback_priority, :description, args: [])
    backend_patch = {}

    backend_patch[:command] = bp[:command] if bp[:command].present?
    backend_patch[:args] = bp[:args] if bp[:args].present?
    backend_patch[:modelArg] = bp[:model_arg] if bp[:model_arg].present?
    backend_patch[:sessionArg] = bp[:session_arg] if bp[:session_arg].present?
    backend_patch[:imageArg] = bp[:image_arg] if bp[:image_arg].present?
    backend_patch[:enabled] = bp[:enabled] == "true" if bp.key?(:enabled)
    backend_patch[:fallbackPriority] = bp[:fallback_priority].to_i if bp[:fallback_priority].present?
    backend_patch[:description] = bp[:description] if bp[:description].present?

    { cliBackends: { backend_id => backend_patch } }
  end
end
