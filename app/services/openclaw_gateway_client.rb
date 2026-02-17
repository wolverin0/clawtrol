# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Minimal HTTP client for the OpenClaw Gateway API.
#
# Used by ClawDeck server-side auto-pull to spawn sessions directly
# (instead of merely waking the agent via /hooks/wake).
class OpenclawGatewayClient
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 30

  def initialize(user, logger: Rails.logger)
    @user = user
    @logger = logger
  end

  # Spawns a sub-agent session.
  #
  # Returns a Hash with:
  # - :child_session_key (String)
  # - :session_id (String, best-effort; resolved via sessions_list)
  def spawn_session!(model:, prompt:)
    res = post_json!("/api/sessions/spawn", body: {
      model: model,
      prompt: prompt
    })

    child_key = res["childSessionKey"] || res["child_session_key"] || res["sessionKey"] || res["session_key"]

    return { child_session_key: child_key, session_id: nil } if child_key.blank?

    # Best-effort: resolve sessionId for live transcript view.
    session_id = resolve_session_id_from_key(child_key)

    { child_session_key: child_key, session_id: session_id }
  end

  def sessions_list
    get_json!("/api/sessions")
  rescue StandardError => e
    { "sessions" => [], "error" => e.message }
  end

  def session_detail(session_key)
    get_json!("/api/sessions/#{session_key}")
  rescue StandardError => e
    { "error" => e.message }
  end

  # --- Gateway Status & Health ---

  def health
    get_json!("/api/health")
  rescue StandardError => e
    { "status" => "unreachable", "error" => e.message }
  end

  # --- Channel Status ---

  def channels_status
    get_json!("/api/channels/status")
  rescue StandardError => e
    { "channels" => [], "error" => e.message }
  end

  # --- Usage & Cost ---

  def usage_cost
    get_json!("/api/usage/cost")
  rescue StandardError => e
    { "error" => e.message }
  end

  # --- Cron Management ---

  def cron_list
    get_json!("/api/cron/list")
  rescue StandardError => e
    { "jobs" => [], "error" => e.message }
  end

  def cron_status
    get_json!("/api/cron/status")
  rescue StandardError => e
    { "error" => e.message }
  end

  def cron_enable(id)
    post_json!("/api/cron/enable", body: { id: id })
  end

  def cron_disable(id)
    post_json!("/api/cron/disable", body: { id: id })
  end

  def cron_create(params)
    post_json!("/api/cron/create", body: params)
  end

  def cron_delete(id)
    post_json!("/api/cron/delete", body: { id: id })
  end

  def cron_update(id, params)
    post_json!("/api/cron/update", body: { id: id }.merge(params))
  end

  def cron_run(id)
    post_json!("/api/cron/run", body: { id: id })
  end

  # --- Models ---

  def models_list
    get_json!("/api/models/list")
  rescue StandardError => e
    { "models" => [], "error" => e.message }
  end

  # --- Agents ---

  def agents_list
    get_json!("/api/agents/list")
  rescue StandardError => e
    { "agents" => [], "error" => e.message }
  end

  # --- Nodes ---

  def nodes_status
    get_json!("/api/nodes/status")
  rescue StandardError => e
    { "nodes" => [], "error" => e.message }
  end

  def node_notify(node_id, title:, body:)
    post_json!("/api/nodes/notify", body: { node: node_id, title: title, body: body })
  end

  # --- Config (read-only, for plugin status) ---

  def config_get
    get_json!("/api/config/get")
  rescue StandardError => e
    { "error" => e.message }
  end

  # Returns the config JSON schema for validation.
  def config_schema
    get_json!("/api/config/schema")
  rescue StandardError => e
    { "error" => e.message }
  end

  # Apply a full config (replaces entire config, then restarts).
  # @param raw [String] raw YAML/JSON config string
  # @param reason [String] optional reason for the change
  def config_apply(raw:, reason: nil)
    body = { raw: raw }
    body[:reason] = reason if reason.present?
    post_json!("/api/config/apply", body: body)
  rescue StandardError => e
    { "error" => e.message }
  end

  # Partial config patch (merges with existing, then restarts).
  # @param raw [String] raw YAML/JSON partial config to merge
  # @param reason [String] optional reason for the change
  def config_patch(raw:, reason: nil)
    body = { raw: raw }
    body[:reason] = reason if reason.present?
    post_json!("/api/config/patch", body: body)
  rescue StandardError => e
    { "error" => e.message }
  end

  # Restart the gateway (SIGUSR1).
  # @param reason [String] optional reason for the restart
  def gateway_restart(reason: nil)
    body = {}
    body[:reason] = reason if reason.present?
    post_json!("/api/gateway/restart", body: body)
  rescue StandardError => e
    { "error" => e.message }
  end

  # Push A2UI HTML content to a node's canvas.
  # @param node [String] node id or name
  # @param html [String] HTML content to render
  # @param width [Integer, nil] optional width
  # @param height [Integer, nil] optional height
  # @return [Hash]
  def canvas_push(node:, html:, width: nil, height: nil)
    validate_gateway_url!
    body = { action: "a2ui_push", node: node, jsonl: html }
    body[:width] = width if width
    body[:height] = height if height
    post_json!("/api/v1/canvas", body: body)
  rescue StandardError => e
    { error: e.message }
  end

  # Take a snapshot of the canvas on a node.
  # @param node [String] node id or name
  # @return [Hash]
  def canvas_snapshot(node:)
    validate_gateway_url!
    post_json!("/api/v1/canvas", body: { action: "snapshot", node: node })
  rescue StandardError => e
    { error: e.message }
  end

  # Hide the canvas on a node.
  # @param node [String] node id or name
  # @return [Hash]
  def canvas_hide(node:)
    validate_gateway_url!
    post_json!("/api/v1/canvas", body: { action: "hide", node: node })
  rescue StandardError => e
    { error: e.message }
  end

  # Returns a structured list of plugins with their enabled/disabled state.
  # Extracts plugin info from the gateway health and config endpoints.
  def plugins_status
    health_data = health
    config_data = config_get

    plugins = extract_plugins(health_data, config_data)
    { "plugins" => plugins, "gateway_version" => health_data["version"] }
  rescue StandardError => e
    { "plugins" => [], "error" => e.message }
  end

  private

  def configured?
    @user.openclaw_gateway_url.present? && @user.openclaw_gateway_token.present?
  end

  def validate_gateway_url!
    raw = @user.openclaw_gateway_url.to_s.strip
    raise "OpenClaw gateway URL missing" if raw.blank?

    if raw.match?(/example/i)
      raise "OpenClaw gateway URL looks like a placeholder (contains 'example')"
    end

    uri = URI.parse(raw)
    unless uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme)
      raise "OpenClaw gateway URL must be http(s)"
    end

    raise "OpenClaw gateway URL missing host" if uri.host.blank?

    # Reject localhost without an explicit port, to avoid accidental port 80/443.
    if uri.host == "localhost" && !raw.match?(/localhost:\d+/)
      raise "OpenClaw gateway URL must include an explicit port for localhost"
    end

    uri
  rescue URI::InvalidURIError
    raise "OpenClaw gateway URL is invalid"
  end

  def base_uri
    @base_uri ||= validate_gateway_url!
  end

  def http_for(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http
  end

  def resolve_session_id_from_key(child_key)
    list = sessions_list
    arr = list.is_a?(Hash) ? (list["sessions"] || list[:sessions]) : list
    sessions = Array(arr)

    found = sessions.find do |s|
      s_key = s["key"] || s[:key]
      s_key.to_s == child_key.to_s
    end

    found && (found["sessionId"] || found["session_id"] || found[:sessionId] || found[:session_id])
  rescue StandardError => e
    @logger.info("[OpenclawGatewayClient] could not resolve session_id from key=#{child_key}: #{e.class}: #{e.message}")
    nil
  end

  def get_json!(path)
    raise "OpenClaw gateway not configured" unless configured?

    uri = base_uri.dup
    uri.path = path

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@user.openclaw_gateway_token}"

    res = http_for(uri).request(req)

    code = res.code.to_i
    body = res.body.to_s

    raise "OpenClaw gateway HTTP #{code}" unless code >= 200 && code < 300

    JSON.parse(body)
  end

  def post_json!(path, body:)
    raise "OpenClaw gateway not configured" unless configured?

    uri = base_uri.dup
    uri.path = path

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@user.openclaw_gateway_token}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json

    res = http_for(uri).request(req)

    code = res.code.to_i
    parsed = JSON.parse(res.body.to_s) rescue { "raw" => res.body.to_s }

    raise "OpenClaw gateway HTTP #{code}: #{parsed}" unless code >= 200 && code < 300

    parsed
  end

  def extract_plugins(health_data, config_data)
    plugins = []

    # Extract from health data (loadedPlugins / plugins array)
    loaded = health_data["loadedPlugins"] || health_data["plugins"] || []
    loaded = Array(loaded)

    loaded.each do |p|
      entry = if p.is_a?(Hash)
        {
          "name" => p["name"] || p["id"] || "unknown",
          "enabled" => p.fetch("enabled", true),
          "version" => p["version"],
          "status" => p["status"] || (p.fetch("enabled", true) ? "active" : "disabled")
        }
      else
        { "name" => p.to_s, "enabled" => true, "status" => "active" }
      end
      plugins << entry
    end

    # If no plugins from health, try config
    if plugins.empty? && config_data.is_a?(Hash)
      config_plugins = config_data.dig("config", "plugins") || config_data["plugins"] || []
      Array(config_plugins).each do |p|
        entry = if p.is_a?(Hash)
          {
            "name" => p["name"] || p["package"] || "unknown",
            "enabled" => p.fetch("enabled", true),
            "version" => p["version"],
            "status" => p.fetch("enabled", true) ? "configured" : "disabled"
          }
        else
          { "name" => p.to_s, "enabled" => true, "status" => "configured" }
        end
        plugins << entry
      end
    end

    plugins.uniq { |p| p["name"] }
  end
end
