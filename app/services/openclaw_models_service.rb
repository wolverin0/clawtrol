# frozen_string_literal: true

require "open3"

# Reads providers + models directly from `openclaw models list --json`.
# Always reflects what's actually configured — no hardcoded lists.
# Cached for 5 minutes to avoid shelling out on every request.
class OpenclawModelsService
  CACHE_KEY = "openclaw_models_v1"
  CACHE_TTL = 5.minutes

  PROVIDER_LABELS = {
    "zai"               => "Z.AI — GLM ($0 · 200K ctx)",
    "anthropic"         => "Anthropic (Claude)",
    "openai-codex"      => "OpenAI Codex",
    "ollama"            => "Ollama (local)",
    "ollama-cloud"      => "Ollama Cloud",
    "openrouter"        => "OpenRouter",
    "groq"              => "Groq (free tier)",
    "cerebras"          => "Cerebras (free tier)",
    "mistral"           => "Mistral",
    "google"            => "Google (Gemini API)",
    "google-gemini-cli" => "Gemini CLI (OAuth)",
    "github-copilot"    => "GitHub Copilot"
  }.freeze

  # zai first (our default $0 model), then free providers, then paid
  PRIORITY = %w[zai groq cerebras google-gemini-cli openrouter ollama mistral google anthropic openai-codex github-copilot].freeze

  def self.providers_with_models
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_from_cli }
  end

  def self.provider_models_map
    providers_with_models.each_with_object({}) do |p, h|
      h[p[:key]] = p[:models]
    end
  end

  def self.providers_for_select
    providers_with_models.map { |p| [p[:label], p[:key]] }
  end

  def self.fetch_from_cli
    stdout, stderr, status = Open3.capture3(openclaw_cli_env, "openclaw", "models", "list", "--json")
    unless status.success?
      raise "openclaw models list failed (exit #{status.exitstatus}): #{stderr.presence || stdout}"
    end

    data = JSON.parse(stdout)

    # Group by provider, only configured models
    by_provider = Hash.new { |h, k| h[k] = [] }
    (data["models"] || []).each do |m|
      next unless m["tags"]&.include?("configured")
      provider = m["key"].split("/").first
      model_id = m["key"].split("/")[1..].join("/")
      by_provider[provider] << model_id
    end

    # Build sorted list
    providers = by_provider.map do |key, models|
      {
        key: key,
        label: PROVIDER_LABELS[key] || key,
        models: models
      }
    end

    providers.sort_by { |p| [PRIORITY.index(p[:key]) || 99, p[:key]] }
  rescue => e
    Rails.logger.warn("[OpenclawModelsService] CLI failed: #{e.message}")
    fallback_providers
  end

  def self.openclaw_cli_env
    return @openclaw_cli_env if defined?(@openclaw_cli_env)

    env = {}
    env_path = File.expand_path("~/.openclaw/.env")

    if File.file?(env_path)
      File.foreach(env_path) do |line|
        line = line.to_s.strip
        next if line.blank? || line.start_with?("#")

        line = line.sub(/\Aexport\s+/, "")
        key, raw_value = line.split("=", 2)
        next if key.blank? || raw_value.nil?

        value = raw_value.strip
        if (value.start_with?("\"") && value.end_with?("\"")) ||
           (value.start_with?("'") && value.end_with?("'"))
          value = value[1..-2]
        end

        env[key] = value
      end
    end

    @openclaw_cli_env = env
  rescue StandardError => e
    Rails.logger.warn("[OpenclawModelsService] Failed to parse ~/.openclaw/.env: #{e.class}: #{e.message}")
    @openclaw_cli_env = {}
  end

  def self.fallback_providers
    [
      { key: "zai",      label: "Z.AI — GLM ($0)",    models: %w[glm-4.7] },
      { key: "groq",     label: "Groq (free)",         models: %w[llama-3.3-70b-versatile] },
      { key: "cerebras", label: "Cerebras (free)",     models: %w[llama-3.3-70b qwen-3-235b-a22b-instruct] }
    ]
  end
end
