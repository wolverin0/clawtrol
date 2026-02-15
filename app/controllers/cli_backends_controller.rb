# frozen_string_literal: true

class CliBackendsController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
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

    patch_and_redirect(
      build_backend_patch(backend_id),
      redirect_path: cli_backends_path,
      cache_key: "cli_backends",
      reason: "CLI backend #{backend_id} updated via ClawTrol",
      success_message: "Backend '#{backend_id}' updated."
    )
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
