# frozen_string_literal: true

# Memory Plugin Dashboard: view memory stats, search memories, and inspect
# OpenClaw memory backends (memory-core, memory-lancedb, QMD).
class MemoryDashboardController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /memory
  def show
    @health_data = gateway_client.health
    @config_data = gateway_client.config_get
    @plugins = extract_memory_plugins(@health_data, @config_data)
    @stats = extract_memory_stats(@health_data, @config_data)
    @search_results = []
    @search_query = ""
  end

  # POST /memory/search
  def search
    @search_query = params[:query].to_s.strip
    @health_data = gateway_client.health
    @config_data = gateway_client.config_get
    @plugins = extract_memory_plugins(@health_data, @config_data)
    @stats = extract_memory_stats(@health_data, @config_data)

    if @search_query.blank?
      @search_results = []
    elsif @search_query.length > 500
      @search_results = []
      flash.now[:alert] = "Query too long (max 500 chars)"
    else
      @search_results = perform_memory_search(@search_query)
    end

    render :show
  end

  private

  MEMORY_PLUGIN_NAMES = %w[
    memory-core memory-lancedb memory
    @openclaw/memory-core @openclaw/memory-lancedb
  ].freeze

  def extract_memory_plugins(health, config)
    plugins = []

    # From health data
    if health.is_a?(Hash)
      loaded = health["loadedPlugins"] || health["plugins"] || []
      Array(loaded).each do |p|
        name = p.is_a?(Hash) ? (p["name"] || p["id"]).to_s : p.to_s
        next unless MEMORY_PLUGIN_NAMES.any? { |mn| name.include?(mn) }

        plugins << {
          name: name,
          enabled: p.is_a?(Hash) ? p.fetch("enabled", true) : true,
          version: p.is_a?(Hash) ? p["version"] : nil,
          status: p.is_a?(Hash) ? (p["status"] || "active") : "active",
          config: p.is_a?(Hash) ? p.except("name", "id", "enabled", "version", "status") : {}
        }
      end
    end

    # From config data
    if plugins.empty? && config.is_a?(Hash)
      raw = config.dig("config") || config
      config_plugins = raw["plugins"] || []
      Array(config_plugins).each do |p|
        name = p.is_a?(Hash) ? (p["name"] || p["package"]).to_s : p.to_s
        next unless MEMORY_PLUGIN_NAMES.any? { |mn| name.include?(mn) }

        plugins << {
          name: name,
          enabled: p.is_a?(Hash) ? p.fetch("enabled", true) : true,
          version: p.is_a?(Hash) ? p["version"] : nil,
          status: "configured",
          config: p.is_a?(Hash) ? p.except("name", "package", "enabled", "version") : {}
        }
      end
    end

    plugins
  end

  def extract_memory_stats(health, config)
    stats = {
      total_entries: nil,
      last_indexed: nil,
      index_size: nil,
      backend: "unknown",
      auto_recall: false,
      auto_capture: false
    }

    # Try to get stats from health
    if health.is_a?(Hash)
      memory_stats = health["memory"] || health["memoryStats"] || {}
      if memory_stats.is_a?(Hash)
        stats[:total_entries] = memory_stats["totalEntries"] || memory_stats["count"]
        stats[:last_indexed] = memory_stats["lastIndexed"] || memory_stats["lastUpdated"]
        stats[:index_size] = memory_stats["indexSize"] || memory_stats["size"]
        stats[:backend] = memory_stats["backend"] || memory_stats["provider"] || "unknown"
      end
    end

    # Check config for auto-recall/capture settings
    if config.is_a?(Hash)
      raw = config.dig("config") || config
      memory_config = raw["memory"] || {}
      if memory_config.is_a?(Hash)
        stats[:auto_recall] = memory_config.fetch("autoRecall", false)
        stats[:auto_capture] = memory_config.fetch("autoCapture", false)
        stats[:backend] = memory_config["backend"] || stats[:backend]
      end
    end

    stats
  end

  def perform_memory_search(query)
    # Use the gateway's memory search API if available
    result = gateway_client.send(:post_json!, "/api/memory/search", body: {
      query: query,
      maxResults: 10,
      minScore: 0.3
    })

    results = result["results"] || result["entries"] || []
    Array(results).map do |r|
      {
        content: r["content"] || r["text"] || r["snippet"],
        score: r["score"] || r["relevance"],
        path: r["path"] || r["source"],
        line: r["line"],
        created_at: r["createdAt"] || r["timestamp"]
      }
    end
  rescue StandardError => e
    Rails.logger.info("[MemoryDashboard] Search failed: #{e.message}")
    []
  end
end
