# frozen_string_literal: true

class SandboxConfigController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  SANDBOX_MODES = %w[docker host none].freeze
  SANDBOX_SCOPES = %w[workspace home full].freeze
  PRESETS = {
    "minimal" => {
      mode: "docker", scope: "workspace", network: false,
      browser: false, resource_limits: true, seccomp: true, apparmor: true
    },
    "standard" => {
      mode: "docker", scope: "workspace", network: true,
      browser: false, resource_limits: true, seccomp: true, apparmor: false
    },
    "full" => {
      mode: "docker", scope: "home", network: true,
      browser: true, resource_limits: false, seccomp: false, apparmor: false
    }
  }.freeze

  # GET /sandbox-config
  def show
    config_data = fetch_config
    @sandbox = extract_sandbox_config(config_data)
    @presets = PRESETS
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /sandbox-config
  def update
    patch = build_sandbox_patch

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Sandbox config updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to sandbox_config_path, alert: "Failed: #{result['error']}"
    else
      invalidate_config_cache("sandbox_cfg")
      redirect_to sandbox_config_path, notice: "Sandbox configuration updated."
    end
  rescue StandardError => e
    redirect_to sandbox_config_path, alert: "Error: #{e.message}"
  end

  private

  def fetch_config
    cached_config_get("sandbox_cfg")
  end

  def extract_sandbox_config(config)
    return default_sandbox if config.nil? || config["error"].present? || config[:error].present?

    sb = config.dig("sandbox") || config.dig(:sandbox) || {}

    {
      mode: sb["mode"] || "docker",
      scope: sb["scope"] || "workspace",
      docker_image: sb["dockerImage"] || sb["image"] || "",
      network: sb["network"] != false,
      browser_sandbox: sb["browserSandbox"] == true || sb["browser"] == true,
      resource_limits: sb["resourceLimits"] != false,
      seccomp: sb["seccomp"] == true,
      apparmor: sb["apparmor"] == true,
      cpu_limit: sb.dig("resources", "cpu") || sb["cpuLimit"] || "",
      memory_limit: sb.dig("resources", "memory") || sb["memoryLimit"] || "",
      workspace_access: sb["workspaceAccess"] || "readwrite",
      per_agent: extract_per_agent_sandbox(config)
    }
  end

  def extract_per_agent_sandbox(config)
    agents = config.dig("agents") || {}
    result = {}
    agents.each do |id, acfg|
      next unless acfg.is_a?(Hash) && acfg["sandbox"].is_a?(Hash)
      result[id] = { mode: acfg.dig("sandbox", "mode"), scope: acfg.dig("sandbox", "scope") }.compact
    end
    result
  end

  def default_sandbox
    {
      mode: "docker", scope: "workspace", docker_image: "", network: true,
      browser_sandbox: false, resource_limits: true, seccomp: false, apparmor: false,
      cpu_limit: "", memory_limit: "", workspace_access: "readwrite", per_agent: {}
    }
  end

  def build_sandbox_patch
    sp = params.permit(:mode, :scope, :docker_image, :network, :browser_sandbox,
                       :resource_limits, :seccomp, :apparmor, :cpu_limit, :memory_limit,
                       :workspace_access, :preset)

    # Apply preset if selected
    if sp[:preset].present? && PRESETS.key?(sp[:preset])
      preset = PRESETS[sp[:preset]]
      return { sandbox: {
        mode: preset[:mode],
        scope: preset[:scope],
        network: preset[:network],
        browserSandbox: preset[:browser],
        resourceLimits: preset[:resource_limits],
        seccomp: preset[:seccomp],
        apparmor: preset[:apparmor]
      } }
    end

    sb_patch = {}
    sb_patch[:mode] = sp[:mode] if sp[:mode].present? && SANDBOX_MODES.include?(sp[:mode])
    sb_patch[:scope] = sp[:scope] if sp[:scope].present? && SANDBOX_SCOPES.include?(sp[:scope])
    sb_patch[:dockerImage] = sp[:docker_image] if sp[:docker_image].present?
    sb_patch[:network] = sp[:network] == "true" if sp.key?(:network)
    sb_patch[:browserSandbox] = sp[:browser_sandbox] == "true" if sp.key?(:browser_sandbox)
    sb_patch[:resourceLimits] = sp[:resource_limits] == "true" if sp.key?(:resource_limits)
    sb_patch[:seccomp] = sp[:seccomp] == "true" if sp.key?(:seccomp)
    sb_patch[:apparmor] = sp[:apparmor] == "true" if sp.key?(:apparmor)
    sb_patch[:workspaceAccess] = sp[:workspace_access] if sp[:workspace_access].present?

    if sp[:cpu_limit].present? || sp[:memory_limit].present?
      sb_patch[:resources] = {}
      sb_patch[:resources][:cpu] = sp[:cpu_limit] if sp[:cpu_limit].present?
      sb_patch[:resources][:memory] = sp[:memory_limit] if sp[:memory_limit].present?
    end

    { sandbox: sb_patch }
  end
end
