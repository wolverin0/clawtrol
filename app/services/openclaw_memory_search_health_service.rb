# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "open3"

# Checks whether OpenClaw's memory_search is functional.
#
# Why not just ping /health?
# - /health can be green while the embeddings provider is failing (400/429),
#   which makes memory_search unusable and degrades agent performance.
#
# This service:
# - performs a cheap memory search request (top_k/limit 1)
# - classifies status: ok / degraded / down
# - caches results for a short window to avoid hammering the gateway
# - persists last error evidence in OpenclawIntegrationStatus
class OpenclawMemorySearchHealthService
  CACHE_TTL = 60.seconds
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 4

  Result = Struct.new(
    :status,
    :last_checked_at,
    :error_message,
    :error_at,
    :gateway_url,
    keyword_init: true
  )

  def initialize(user, cache: Rails.cache, logger: Rails.logger)
    @user = user
    @cache = cache
    @logger = logger
  end

  def call
    return Result.new(status: :unknown) unless configured?

    @cache.fetch(cache_key, expires_in: CACHE_TTL) do
      check_and_persist!
    end
  end

  private

  def configured?
    @user.openclaw_gateway_url.present? && @user.openclaw_gateway_token.present?
  end

  def cache_key
    "openclaw:memory_search_health:user:#{@user.id}"
  end

  def check_and_persist!
    now = Time.current

    # 1) Ensure gateway is reachable first (fast fail)
    health = get_json("/health", authorized: false)
    unless health[:ok]
      return persist!(
        status: :down,
        last_checked_at: now,
        error_message: "Gateway unreachable: #{health[:error]}",
        error_at: now
      )
    end

    # 2) Probe memory_search via CLI (OpenClaw has no HTTP API for memory_search)
    search = probe_memory_via_cli
    unless search[:ok]
      return persist!(
        status: search[:status] || :degraded,
        last_checked_at: now,
        error_message: "memory_search: #{search[:error]}",
        error_at: now
      )
    end

    persist!(status: :ok, last_checked_at: now, error_message: nil, error_at: nil)
  rescue StandardError => e
    @logger.error("[OpenclawMemorySearchHealthService] user_id=#{@user.id} err=#{e.class}: #{e.message}")

    persist!(
      status: :down,
      last_checked_at: Time.current,
      error_message: "Exception: #{e.class}: #{e.message}",
      error_at: Time.current
    )
  end

  def probe_memory_via_cli
    stdout, stderr, status = Open3.capture3(
      "openclaw", "memory", "status", "--json", "--deep",
      chdir: File.expand_path("~")
    )

    unless status.success?
      return { ok: false, status: :down, error: "CLI failed: #{stderr.to_s.truncate(200)}" }
    end

    json = JSON.parse(stdout) rescue nil
    return { ok: false, status: :degraded, error: "Invalid CLI output" } unless json

    # CLI returns array of agents; check the "main" agent
    entry = json.is_a?(Array) ? json.find { |e| e["agentId"] == "main" } || json.first : json
    return { ok: false, status: :degraded, error: "No agent entry found" } unless entry

    probe_ok = entry.dig("embeddingProbe", "ok")
    if probe_ok == false
      { ok: false, status: :degraded, error: "Embedding provider unavailable" }
    else
      { ok: true }
    end
  rescue Errno::ENOENT
    { ok: false, status: :down, error: "openclaw CLI not found in PATH" }
  rescue StandardError => e
    { ok: false, status: :degraded, error: "CLI probe: #{e.message}" }
  end

  def classify_memory_error(http_code, error)
    code = http_code.to_i

    # Embeddings provider errors / quota exhaustion => degraded
    return :degraded if [ 400, 401, 403, 429 ].include?(code)

    # Gateway/server errors => down
    return :down if code >= 500 || code.zero?

    # Unknown client errors
    error.to_s.match?(/RESOURCE_EXHAUSTED|quota|rate/i) ? :degraded : :degraded
  end

  def base_uri
    URI.parse(@user.openclaw_gateway_url)
  end

  def http_for(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http
  end

  def get_json(path, authorized:)
    uri = base_uri.dup
    uri.path = path

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@user.openclaw_gateway_token}" if authorized

    res = http_for(uri).request(req)

    ok = res.code.to_i >= 200 && res.code.to_i < 300
    return { ok: true, http_code: res.code.to_i, json: safe_parse_json(res.body) } if ok

    { ok: false, http_code: res.code.to_i, error: "HTTP #{res.code}" }
  rescue StandardError => e
    { ok: false, http_code: 0, error: e.message }
  end

  def post_json(path, body:)
    uri = base_uri.dup
    uri.path = path

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{@user.openclaw_gateway_token}"
    req.body = body.to_json

    res = http_for(uri).request(req)

    ok = res.code.to_i >= 200 && res.code.to_i < 300
    return { ok: true, http_code: res.code.to_i, json: safe_parse_json(res.body) } if ok

    err = safe_parse_json(res.body)
    msg = if err.is_a?(Hash)
      err["error"] || err["message"] || err.to_s
    else
      err.to_s
    end

    { ok: false, http_code: res.code.to_i, error: msg.presence || "HTTP #{res.code}" }
  rescue StandardError => e
    { ok: false, http_code: 0, error: e.message }
  end

  def safe_parse_json(body)
    return nil if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    body.to_s
  end

  def status_record
    @user.openclaw_integration_status || @user.build_openclaw_integration_status
  end

  def persist!(status:, last_checked_at:, error_message:, error_at:)
    rec = status_record
    rec.memory_search_status = status
    rec.memory_search_last_checked_at = last_checked_at

    if error_message.present?
      rec.memory_search_last_error = error_message.to_s.truncate(2000)
      rec.memory_search_last_error_at = error_at
    end

    # Don't erase last error evidence on success; it can be useful for operator.
    rec.save!

    Result.new(
      status: status,
      last_checked_at: rec.memory_search_last_checked_at,
      error_message: rec.memory_search_last_error,
      error_at: rec.memory_search_last_error_at,
      gateway_url: @user.openclaw_gateway_url
    )
  end
end
