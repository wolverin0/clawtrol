# frozen_string_literal: true

class CompactionConfigController < ApplicationController
  include GatewayClientAccessible
  include GatewayConfigPatchable
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  COMPACTION_MODES = %w[safeguard eager never].freeze

  # GET /compaction-config
  def show
    config_data = fetch_config
    @compaction = extract_compaction_config(config_data)
    @pruning = extract_pruning_config(config_data)
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /compaction-config
  def update
    patch_and_redirect(
      build_patch,
      redirect_path: compaction_config_path,
      cache_key: "compaction_cfg",
      reason: "Compaction/pruning config updated via ClawTrol",
      success_message: "Compaction & pruning config updated."
    )
  end

  private

  def fetch_config
    cached_config_get("compaction_cfg")
  end

  def extract_compaction_config(config)
    return default_compaction if config.nil? || config["error"].present? || config[:error].present?

    comp = config.dig("compaction") || config.dig(:compaction) || {}

    {
      mode: comp["mode"] || "safeguard",
      memory_flush: comp["memoryFlush"] != false,
      summary_model: comp["summaryModel"] || "",
      max_turns_before_compact: comp["maxTurnsBeforeCompact"] || 50
    }
  end

  def extract_pruning_config(config)
    return default_pruning if config.nil? || config["error"].present? || config[:error].present?

    prune = config.dig("contextPruning") || config.dig(:context_pruning) || {}

    {
      cache_ttl_minutes: prune["cacheTtl"] || prune["cacheTtlMinutes"] || 30,
      soft_trim_ratio: prune["softTrimRatio"] || 0.8,
      hard_trim_ratio: prune["hardTrimRatio"] || 0.9,
      preserve_system: prune["preserveSystem"] != false
    }
  end

  def default_compaction
    { mode: "safeguard", memory_flush: true, summary_model: "", max_turns_before_compact: 50 }
  end

  def default_pruning
    { cache_ttl_minutes: 30, soft_trim_ratio: 0.8, hard_trim_ratio: 0.9, preserve_system: true }
  end

  def build_patch
    cp = params.permit(:comp_mode, :memory_flush, :summary_model, :max_turns,
                       :cache_ttl, :soft_trim_ratio, :hard_trim_ratio, :preserve_system)

    compaction_patch = {}
    pruning_patch = {}

    if cp[:comp_mode].present? && COMPACTION_MODES.include?(cp[:comp_mode])
      compaction_patch[:mode] = cp[:comp_mode]
    end

    compaction_patch[:memoryFlush] = cp[:memory_flush] == "true" if cp.key?(:memory_flush)
    compaction_patch[:summaryModel] = cp[:summary_model] if cp[:summary_model].present?

    if cp[:max_turns].present?
      compaction_patch[:maxTurnsBeforeCompact] = cp[:max_turns].to_i.clamp(10, 500)
    end

    if cp[:cache_ttl].present?
      pruning_patch[:cacheTtl] = cp[:cache_ttl].to_i.clamp(5, 1440)
    end

    if cp[:soft_trim_ratio].present?
      pruning_patch[:softTrimRatio] = cp[:soft_trim_ratio].to_f.clamp(0.1, 0.95)
    end

    if cp[:hard_trim_ratio].present?
      pruning_patch[:hardTrimRatio] = cp[:hard_trim_ratio].to_f.clamp(0.5, 0.99)
    end

    pruning_patch[:preserveSystem] = cp[:preserve_system] == "true" if cp.key?(:preserve_system)

    result = {}
    result[:compaction] = compaction_patch if compaction_patch.any?
    result[:contextPruning] = pruning_patch if pruning_patch.any?
    result
  end
end
