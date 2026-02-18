# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Minimal HTTP client for the OpenClaw Gateway API.
#
# The Gateway exposes everything through POST /tools/invoke.
# There are NO direct REST endpoints like /api/sessions — those don't exist
# and the gateway returns its SPA HTML as a catch-all fallback.
#
# All methods call POST /tools/invoke with the appropriate tool name and args.
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
    result = invoke_tool!("sessions_spawn", args: { model: model, task: prompt })
    details = extract_details(result)

    child_key = details["childSessionKey"] || details["child_session_key"] ||
                details["sessionKey"] || details["session_key"]

    return { child_session_key: child_key, session_id: nil } if child_key.blank?

    # Best-effort: resolve sessionId for live transcript view.
    session_id = resolve_session_id_from_key(child_key)

    { child_session_key: child_key, session_id: session_id }
  end

  def sessions_list
    result = invoke_tool!("sessions_list", args: {})
    extract_details(result) || { "sessions" => [] }
  rescue StandardError => e
    { "sessions" => [], "error" => e.message }
  end

  def session_detail(session_key)
    list = sessions_list
    sessions = Array(list["sessions"] || list[:sessions] || [])
    found = sessions.find { |s| (s["key"] || s[:key]).to_s == session_key.to_s }
    found || { "error" => "Session not found: #{session_key}" }
  rescue StandardError => e
    { "error" => e.message }
  end

  # --- Gateway Status & Health ---

  def health
    result = invoke_tool!("session_status", args: {})
    extract_details(result) || { "status" => "ok" }
  rescue StandardError => e
    { "status" => "unreachable", "error" => e.message }
  end

  # --- Channel Status ---

  def channels_status
    result = invoke_tool!("gateway", action: "config.get", args: {})
    details = extract_details(result) || {}
    # Extract channel info from config
    config = details["config"] || details
    channels = config.dig("channels") || []
    { "channels" => Array(channels) }
  rescue StandardError => e
    { "channels" => [], "error" => e.message }
  end

  # --- Usage & Cost ---

  def usage_cost
    result = invoke_tool!("session_status", args: {})
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  # --- Cron Management ---

  def cron_list
    result = invoke_tool!("cron", action: "list", args: {})
    extract_details(result) || { "jobs" => [] }
  rescue StandardError => e
    { "jobs" => [], "error" => e.message }
  end

  def cron_status
    result = invoke_tool!("cron", action: "status", args: {})
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  def cron_enable(id)
    result = invoke_tool!("cron", action: "enable", args: { id: id })
    extract_details(result) || {}
  end

  def cron_disable(id)
    result = invoke_tool!("cron", action: "disable", args: { id: id })
    extract_details(result) || {}
  end

  def cron_create(params)
    result = invoke_tool!("cron", action: "add", args: params)
    extract_details(result) || {}
  end

  def cron_delete(id)
    result = invoke_tool!("cron", action: "remove", args: { jobId: id })
    extract_details(result) || {}
  end

  def cron_update(id, params)
    result = invoke_tool!("cron", action: "update", args: { jobId: id }.merge(params))
    extract_details(result) || {}
  end

  def cron_run(id)
    result = invoke_tool!("cron", action: "run", args: { jobId: id })
    extract_details(result) || {}
  end

  # --- Models ---

  def models_list
    result = invoke_tool!("session_status", args: {})
    details = extract_details(result) || {}
    # session_status doesn't list all models; return what we have or empty
    { "models" => Array(details["models"] || []) }
  rescue StandardError => e
    { "models" => [], "error" => e.message }
  end

  # --- Agents ---

  def agents_list
    result = invoke_tool!("agents_list", args: {})
    extract_details(result) || { "agents" => [] }
  rescue StandardError => e
    { "agents" => [], "error" => e.message }
  end

  # --- Nodes ---

  def nodes_status
    result = invoke_tool!("nodes", action: "status", args: {})
    extract_details(result) || { "nodes" => [] }
  rescue StandardError => e
    { "nodes" => [], "error" => e.message }
  end

  def node_notify(node_id, title:, body:)
    result = invoke_tool!("nodes", action: "notify", args: { node: node_id, title: title, body: body })
    extract_details(result) || {}
  end

  # --- Config (read-only, for plugin status) ---

  # --- Sessions Chat ---

  # Send a message to an agent session via /hooks/agent.
  # /api/sessions/send does NOT exist in OpenClaw — this is the correct endpoint.
  def sessions_send(session_key, message)
    hooks_token = @user.try(:openclaw_hooks_token).presence || @user.openclaw_gateway_token

    uri = base_uri.dup
    uri.path = "/hooks/agent"

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{hooks_token}"
    req["Content-Type"] = "application/json"
    req.body = {
      message: message,
      sessionKey: session_key,
      deliver: false,
      name: "ClawTrol Chat"
    }.to_json

    res = http_for(uri).request(req)
    JSON.parse(res.body)
  rescue StandardError => e
    { "ok" => false, "error" => e.message }
  end

  # Read session transcript from local JSONL file (no HTTP endpoint exists for this).
  def sessions_history(session_key, limit: 20)
    sessions_dir = File.expand_path("~/.openclaw/agents/main/sessions")
    store_file = File.join(sessions_dir, "sessions.json")
    return { "messages" => [], "error" => "sessions.json not found" } unless File.exist?(store_file)

    store = JSON.parse(File.read(store_file))
    entry = store[session_key]
    return { "messages" => [], "error" => "session not found" } unless entry

    session_id = entry["sessionId"]
    transcript_file = File.join(sessions_dir, "#{session_id}.jsonl")
    return { "messages" => [], "error" => "transcript not found" } unless File.exist?(transcript_file)

    messages = []
    File.readlines(transcript_file).last(limit * 3).each do |line|
      begin
        msg = JSON.parse(line.strip)
        next unless %w[user assistant].include?(msg["role"])
        content_text = if msg["content"].is_a?(Array)
          msg["content"].select { |c| c["type"] == "text" }.map { |c| c["text"] }.join("\n")
        else
          msg["content"].to_s
        end
        next if content_text.blank?
        messages << {
          "role" => msg["role"],
          "content" => content_text,
          "timestamp" => msg["timestamp"]
        }
      rescue JSON::ParserError
        next
      end
    end

    { "messages" => messages.last(limit) }
  rescue StandardError => e
    { "messages" => [], "error" => e.message }
  end

  def config_get
    result = invoke_tool!("gateway", action: "config.get", args: {})
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  # Returns the config JSON schema for validation.
  def config_schema
    result = invoke_tool!("gateway", action: "config.schema", args: {})
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  # Apply a full config (replaces entire config, then restarts).
  # @param raw [String] raw YAML/JSON config string
  # @param reason [String] optional reason for the change
  def config_apply(raw:, reason: nil)
    args = { raw: raw }
    args[:reason] = reason if reason.present?
    result = invoke_tool!("gateway", action: "config.apply", args: args)
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  # Partial config patch (merges with existing, then restarts).
  # @param raw [String] raw YAML/JSON partial config to merge
  # @param reason [String] optional reason for the change
  def config_patch(raw:, reason: nil)
    args = { raw: raw }
    args[:reason] = reason if reason.present?
    result = invoke_tool!("gateway", action: "config.patch", args: args)
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  # Restart the gateway (SIGUSR1).
  # @param reason [String] optional reason for the restart
  def gateway_restart(reason: nil)
    args = {}
    args[:reason] = reason if reason.present?
    result = invoke_tool!("gateway", action: "restart", args: args)
    extract_details(result) || {}
  rescue StandardError => e
    { "error" => e.message }
  end

  # Push A2UI HTML content to a node's canvas.
  def canvas_push(node:, html:, width: nil, height: nil)
    args = { action: "a2ui_push", node: node, jsonl: html }
    args[:width] = width if width
    args[:height] = height if height
    result = invoke_tool!("canvas", action: "a2ui_push", args: args)
    extract_details(result) || {}
  rescue StandardError => e
    { error: e.message }
  end

  # Take a snapshot of the canvas on a node.
  def canvas_snapshot(node:)
    result = invoke_tool!("canvas", action: "snapshot", args: { node: node })
    extract_details(result) || {}
  rescue StandardError => e
    { error: e.message }
  end

  # Hide the canvas on a node.
  def canvas_hide(node:)
    result = invoke_tool!("canvas", action: "hide", args: { node: node })
    extract_details(result) || {}
  rescue StandardError => e
    { error: e.message }
  end

  # Returns a structured list of plugins with their enabled/disabled state.
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

  # Core method: POST /tools/invoke with tool + optional action + args.
  # Returns the raw parsed JSON response.
  def invoke_tool!(tool, action: nil, args: {}, session_key: "main")
    raise "OpenClaw gateway not configured" unless configured?

    uri = base_uri.dup
    uri.path = "/tools/invoke"

    body = { tool: tool, args: args, sessionKey: session_key }
    body[:action] = action if action.present?

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@user.openclaw_gateway_token}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json

    res = http_for(uri).request(req)
    code = res.code.to_i
    raw  = res.body.to_s

    # Detect HTML catch-all response (gateway SPA fallback)
    if raw.lstrip.start_with?("<!") || raw.lstrip.start_with?("<html")
      raise "OpenClaw gateway returned HTML instead of JSON — endpoint not found (tool=#{tool})"
    end

    parsed = JSON.parse(raw)

    unless code >= 200 && code < 300
      err = parsed["error"] || parsed["message"] || raw
      raise "OpenClaw gateway HTTP #{code}: #{err}"
    end

    unless parsed["ok"]
      raise "OpenClaw gateway tool error: #{parsed["error"] || parsed.inspect}"
    end

    parsed
  end

  # Extracts the details hash from a /tools/invoke response.
  # The gateway puts the parsed result in result.details.
  # Falls back to parsing result.content[0].text if details is missing.
  def extract_details(response)
    return nil unless response.is_a?(Hash)

    result = response["result"]
    return nil unless result.is_a?(Hash)

    # Prefer the pre-parsed details field
    details = result["details"]
    return details if details.is_a?(Hash)

    # Fall back to parsing the text content
    content = result["content"]
    if content.is_a?(Array)
      text_item = content.find { |c| c.is_a?(Hash) && c["type"] == "text" }
      if text_item
        parsed = JSON.parse(text_item["text"]) rescue nil
        return parsed if parsed.is_a?(Hash)
      end
    end

    nil
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

  def extract_plugins(health_data, config_data)
    plugins = []

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
