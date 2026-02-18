# frozen_string_literal: true

class ModelCatalogService
  CACHE_TTL = 5.minutes

  def initialize(user, cache: Rails.cache, gateway_client_class: OpenclawGatewayClient)
    @user = user
    @cache = cache
    @gateway_client_class = gateway_client_class
  end

  def model_ids
    return Task::MODELS.dup if @user.blank?

    @cache.fetch(cache_key, expires_in: CACHE_TTL) { build_catalog }
  rescue StandardError
    fallback_catalog
  end

  private

  def cache_key
    "model_catalog:user:#{@user.id}:v1"
  end

  def build_catalog
    ids = []
    ids.concat(extract_model_ids(fetch_gateway_models))

    ids.concat(@user.tasks.where.not(model: [nil, ""]).distinct.pluck(:model))
    ids.concat(@user.agent_personas.where.not(model: [nil, ""]).distinct.pluck(:model)) if @user.respond_to?(:agent_personas)
    ids.concat(@user.model_limits.where.not(name: [nil, ""]).distinct.pluck(:name)) if @user.respond_to?(:model_limits)

    fb = @user.fallback_model_chain.to_s
    if fb.present?
      ids.concat(fb.split(/[\n,>]+/).map(&:strip))
    end

    ids.concat(Task::MODELS)

    normalize(ids)
  end

  def fallback_catalog
    ids = []
    ids.concat(@user.tasks.where.not(model: [nil, ""]).distinct.pluck(:model)) if @user.present?
    ids.concat(Task::MODELS)
    normalize(ids)
  end

  def fetch_gateway_models
    return {} if @user.openclaw_gateway_url.to_s.strip.blank?

    token = if @user.respond_to?(:openclaw_hooks_token)
      @user.openclaw_hooks_token.to_s.strip
    else
      ""
    end
    token = @user.openclaw_gateway_token.to_s.strip if token.blank?
    return {} if token.blank?

    @gateway_client_class.new(@user).models_list
  rescue StandardError
    {}
  end

  def extract_model_ids(payload)
    ids = []

    case payload
    when Array
      payload.each { |item| ids.concat(extract_model_ids(item)) }
    when Hash
      if payload.key?("models") || payload.key?(:models)
        ids.concat(extract_model_ids(payload["models"] || payload[:models]))
      end

      providers = payload.dig("models", "providers") || payload.dig(:models, :providers) || payload["providers"] || payload[:providers]
      if providers.is_a?(Hash)
        providers.each_value do |provider_cfg|
          provider_models = provider_cfg.is_a?(Hash) ? (provider_cfg["models"] || provider_cfg[:models]) : nil
          if provider_models.is_a?(Hash)
            ids.concat(provider_models.keys)
          elsif provider_models.is_a?(Array)
            ids.concat(provider_models)
          end
        end
      end

      model_id = payload["id"] || payload[:id] || payload["model"] || payload[:model] || payload["name"] || payload[:name]
      ids << model_id if model_id.present?
    when String
      ids << payload
    end

    ids
  end

  def normalize(ids)
    cleaned = ids.map { |id| id.to_s.strip }.reject(&:blank?).uniq
    preferred = Task::MODELS.select { |m| cleaned.include?(m) }
    extra = (cleaned - preferred).sort
    preferred + extra
  end
end
