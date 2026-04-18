# frozen_string_literal: true

# Central OpenClaw / external-service URL configuration.
# All URLs come from ENV so the app is portable between LAN, cloud,
# and staging deployments. Fallbacks are the original LAN defaults
# for backward compatibility with existing dev boxes.
Rails.application.config.x.openclaw = ActiveSupport::OrderedOptions.new.tap do |cfg|
  cfg.gateway_url  = ENV.fetch("OPENCLAW_GATEWAY_URL", "http://192.168.100.186:18789")
  cfg.docs_hub_url = ENV.fetch("DOCS_HUB_URL",         "http://192.168.100.186:4010")
  cfg.qdrant_url   = ENV.fetch("QDRANT_URL",           "http://192.168.100.186:6333")
  cfg.ollama_url   = ENV.fetch("OLLAMA_URL",           "http://192.168.100.155:11434")
end

if Rails.env.production?
  required = %w[OPENCLAW_GATEWAY_URL DOCS_HUB_URL QDRANT_URL OLLAMA_URL]
  missing = required.reject { |k| ENV[k].to_s.strip.length.positive? }
  unless missing.empty?
    Rails.logger.warn(
      "[openclaw_config] production env var(s) missing, using LAN defaults: " + missing.join(", ")
    )
  end
end
