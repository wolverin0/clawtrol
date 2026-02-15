# frozen_string_literal: true

# Manage OpenClaw skills: browse installed (bundled + workspace + managed),
# configure per-skill env vars, enable/disable, and sync with ClawHub.
#
# Skills are read from the gateway config's `skills` section and
# the workspace skills directory on disk.
class SkillManagerController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  MAX_SKILL_NAME = 100
  MAX_ENV_VALUE  = 4096

  # GET /skills
  def index
    config   = gateway_client.config_get
    @health  = gateway_client.health
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}

    @skills_config = raw_conf.dig("skills") || {}
    @installed     = discover_skills(raw_conf)
    @stats         = compute_stats(@installed)
  end

  # POST /skills/:name/toggle — enable or disable a skill
  def toggle
    name = sanitize_skill_name(params[:name])
    return render_bad_name unless name

    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    skills   = (raw_conf["skills"] || {}).deep_dup

    # Merge into the per-skill entry
    skills[name] ||= {}
    skills[name]["enabled"] = enabled

    apply_skills_patch(skills)
  end

  # POST /skills/:name/configure — update per-skill env vars or config
  def configure
    name = sanitize_skill_name(params[:name])
    return render_bad_name unless name

    env_json = params[:env_vars].to_s.strip
    env_hash = {}

    if env_json.present?
      begin
        parsed = JSON.parse(env_json)
        unless parsed.is_a?(Hash) && parsed.all? { |k, v| k.is_a?(String) && v.is_a?(String) && v.length <= MAX_ENV_VALUE }
          return render json: { success: false, error: "Invalid env vars — must be a flat JSON object of strings" }, status: :unprocessable_entity
        end
        env_hash = parsed
      rescue JSON::ParserError
        return render json: { success: false, error: "Invalid JSON in env vars" }, status: :unprocessable_entity
      end
    end

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    skills   = (raw_conf["skills"] || {}).deep_dup

    skills[name] ||= {}
    skills[name]["env"] = env_hash if env_hash.any?
    skills[name].delete("env") if env_hash.empty?

    apply_skills_patch(skills)
  end

  # POST /skills/install — install a skill from ClawHub
  def install
    name = sanitize_skill_name(params[:skill_name])
    return render_bad_name unless name

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    skills   = (raw_conf["skills"] || {}).deep_dup

    skills[name] ||= {}
    skills[name]["enabled"] = true

    apply_skills_patch(skills)
  end

  # DELETE /skills/:name — remove a skill from config
  def uninstall
    name = sanitize_skill_name(params[:name])
    return render_bad_name unless name

    config   = gateway_client.config_get
    raw_conf = config.is_a?(Hash) ? (config["config"] || config) : {}
    skills   = (raw_conf["skills"] || {}).deep_dup

    skills.delete(name)

    apply_skills_patch(skills)
  end

  private

  def sanitize_skill_name(raw)
    return nil if raw.blank?

    clean = raw.to_s.strip.downcase.gsub(/[^a-z0-9_-]/, "").first(MAX_SKILL_NAME)
    clean.present? ? clean : nil
  end

  def render_bad_name
    render json: { success: false, error: "Invalid skill name" }, status: :unprocessable_entity
  end

  def apply_skills_patch(skills_hash)
    patch  = { "skills" => skills_hash }
    result = gateway_client.config_patch(
      raw:    patch.to_json,
      reason: "Skills config updated from ClawTrol"
    )

    if result["error"].present?
      render json: { success: false, error: result["error"] }, status: :unprocessable_entity
    else
      render json: { success: true, message: "Skills config saved. Gateway restarting…" }
    end
  end

  # Discover skills from multiple sources:
  #  1. Bundled (from health data or known list)
  #  2. Workspace (from skills config or disk)
  #  3. Managed (explicit in config)
  def discover_skills(raw_conf)
    skills_conf = raw_conf.dig("skills") || {}
    all_skills  = {}

    # 1. Skills explicitly in config
    skills_conf.each do |key, val|
      next if %w[allowBundled load].include?(key)
      next unless val.is_a?(Hash) || val == true

      cfg = val.is_a?(Hash) ? val : {}
      all_skills[key] = {
        name:        key,
        source:      cfg["location"].present? ? detect_source(cfg["location"]) : "config",
        enabled:     cfg.fetch("enabled", true),
        location:    cfg["location"],
        description: cfg["description"],
        env_keys:    (cfg["env"] || {}).keys,
        gating:      cfg["gating"] || {},
        config:      cfg
      }
    end

    # 2. Well-known bundled skills (if allowBundled not explicitly false)
    allow_bundled = skills_conf.fetch("allowBundled", true)
    if allow_bundled
      bundled_skills.each do |bs|
        next if all_skills.key?(bs[:name])

        all_skills[bs[:name]] = bs.merge(source: "bundled", enabled: true, config: {})
      end
    end

    # 3. Extra dirs
    extra_dirs = Array(skills_conf.dig("load", "extraDirs"))
    extra_dirs.each do |dir|
      all_skills.values
        .select { |s| s[:location]&.start_with?(dir) }
        .each { |s| s[:source] = "workspace" }
    end

    all_skills.values.sort_by { |s| [source_order(s[:source]), s[:name]] }
  end

  def detect_source(location)
    return "workspace" if location&.include?(".openclaw/workspace")
    return "bundled"   if location&.include?("node_modules/openclaw")

    "managed"
  end

  def source_order(src)
    { "bundled" => 0, "workspace" => 1, "managed" => 2, "config" => 3 }[src] || 4
  end

  def compute_stats(skills_list)
    {
      total:     skills_list.size,
      enabled:   skills_list.count { |s| s[:enabled] },
      disabled:  skills_list.count { |s| !s[:enabled] },
      bundled:   skills_list.count { |s| s[:source] == "bundled" },
      workspace: skills_list.count { |s| s[:source] == "workspace" },
      managed:   skills_list.count { |s| %w[managed config].include?(s[:source]) }
    }
  end

  def bundled_skills
    [
      { name: "clawhub",           description: "Search, install, update, and publish skills from clawhub.com" },
      { name: "coding-agent",      description: "Run Codex CLI, Claude Code, OpenCode, or Pi Coding Agent" },
      { name: "gemini",            description: "Gemini CLI for Q&A, summaries, and generation" },
      { name: "github",            description: "Interact with GitHub using the gh CLI" },
      { name: "healthcheck",       description: "Host security hardening and risk-tolerance configuration" },
      { name: "mcporter",          description: "List, configure, auth, and call MCP servers/tools" },
      { name: "openai-image-gen",  description: "Batch-generate images via OpenAI Images API" },
      { name: "openai-whisper-api", description: "Transcribe audio via OpenAI Whisper API" },
      { name: "oracle",            description: "Oracle CLI for prompt + file bundling, engines, sessions" },
      { name: "skill-creator",     description: "Create or update AgentSkills" },
      { name: "video-frames",      description: "Extract frames or clips from videos with ffmpeg" },
      { name: "weather",           description: "Get current weather and forecasts" }
    ]
  end
end
