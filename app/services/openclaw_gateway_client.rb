# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "cgi"

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
  end

  # --- Gateway Status & Health ---

  def health
    uri = base_uri.dup
    uri.path = "/health"

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@user.openclaw_gateway_token}"
    res = http_for(uri).request(req)

    code = res.code.to_i
    body = res.body.to_s

    return { "status" => "unreachable", "error" => "OpenClaw gateway HTTP #{code}" } unless code >= 200 && code < 300

    begin
      JSON.parse(body)
    rescue JSON::ParserError
      { "status" => "ok" }
    end
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

  def cron_run(id)
    post_json!("/api/cron/run", body: { id: id })
  end

  # --- Models ---

  def models_list
    get_json!("/api/models/list")
  rescue StandardError => e
    { "models" => [], "error" => e.message }
  end

  # --- Chat / Session Messaging ---

  # Send a message to an agent session via OpenClaw webhook endpoint.
  # /api/sessions/send does not exist in gateway HTTP API.
  def sessions_send(session_key, message)
    hooks_token = @user.openclaw_hooks_token.presence || @user.openclaw_gateway_token

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
  end

  # Retrieve recent chat/session history from local OpenClaw transcript files.
  # Session transcripts are stored at ~/.openclaw/agents/main/sessions/<sessionId>.jsonl
  def sessions_history(session_key, limit: 20)
    sessions_dir = File.expand_path("~/.openclaw/agents/main/sessions")
    store_file = File.join(sessions_dir, "sessions.json")

    return { "messages" => [], "error" => "sessions.json not found" } unless File.exist?(store_file)

    store = JSON.parse(File.read(store_file))
    # Try exact key first, then with agent prefix (OpenClaw stores as agent:main:<key>)
    entry = store[session_key] || store["agent:main:#{session_key}"]
    return { "messages" => [], "error" => "session not found" } unless entry

    session_id = entry["sessionId"]
    transcript_file = File.join(sessions_dir, "#{session_id}.jsonl")
    return { "messages" => [], "error" => "transcript not found" } unless File.exist?(transcript_file)

    messages = []
    File.readlines(transcript_file).last(limit * 3).each do |line|
      begin
        entry_data = JSON.parse(line.strip)
        # OpenClaw JSONL format: { type: "message", message: { role: "user", content: [...] } }
        inner = entry_data["message"] || entry_data
        next unless %w[user assistant].include?(inner["role"])

        raw_content = inner["content"]
        content_text = if raw_content.is_a?(Array)
          raw_content.select { |c| c["type"] == "text" }.map { |c| c["text"] }.join("\n")
        else
          raw_content.to_s
        end

        next if content_text.blank?

        messages << {
          "role" => inner["role"],
          "content" => content_text,
          "timestamp" => entry_data["timestamp"] || inner["timestamp"]
        }
      rescue JSON::ParserError
        next
      end
    end

    { "messages" => messages.last(limit) }
  rescue StandardError => e
    { "messages" => [], "error" => e.message }
  end

  # --- Agents ---

  def agents_list
    get_json!("/api/agents/list")
  rescue StandardError => e
    { "agents" => [], "error" => e.message }
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
end
