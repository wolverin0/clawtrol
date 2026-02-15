# frozen_string_literal: true

class ModelProvidersController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /model-providers
  def index
    config_data = fetch_config
    @providers = extract_providers(config_data)
    @models_list = fetch_models_list
    @error = config_data["error"] || config_data[:error] if config_data.is_a?(Hash)
  end

  # PATCH /model-providers
  def update
    provider_id = params[:provider_id].to_s.strip
    if provider_id.blank?
      redirect_to model_providers_path, alert: "Provider ID required"
      return
    end

    patch = build_provider_patch(provider_id)

    result = gateway_client.config_patch(
      raw: patch.to_json,
      reason: "Model provider #{provider_id} updated via ClawTrol"
    )

    if result["error"].present?
      redirect_to model_providers_path, alert: "Failed: #{result['error']}"
    else
      Rails.cache.delete("model_providers/#{current_user.id}")
      redirect_to model_providers_path, notice: "Provider '#{provider_id}' updated."
    end
  rescue StandardError => e
    redirect_to model_providers_path, alert: "Error: #{e.message}"
  end

  # POST /model-providers/test
  def test_provider
    base_url = params[:base_url].to_s.strip
    api_key = params[:api_key].to_s.strip
    model = params[:model].to_s.strip

    if base_url.blank? || model.blank?
      render json: { error: "Base URL and model are required" }, status: :unprocessable_entity
      return
    end

    # Simple connectivity test: send a minimal request
    uri = URI.parse("#{base_url.chomp('/')}/chat/completions")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{api_key}" if api_key.present?
    req.body = {
      model: model,
      messages: [{ role: "user", content: "Say 'ok'" }],
      max_tokens: 5
    }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 15

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    res = http.request(req)
    latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    if res.code.to_i >= 200 && res.code.to_i < 300
      parsed = JSON.parse(res.body) rescue {}
      content = parsed.dig("choices", 0, "message", "content") || "(no content)"
      render json: { success: true, latency_ms: latency_ms, response: content.truncate(100), status: res.code }
    else
      render json: { error: "HTTP #{res.code}: #{res.body.to_s.truncate(200)}", latency_ms: latency_ms }
    end
  rescue StandardError => e
    render json: { error: e.message }
  end

  private

  def fetch_config
    Rails.cache.fetch("model_providers/#{current_user.id}", expires_in: 30.seconds) do
      gateway_client.config_get
    end
  rescue StandardError => e
    { error: e.message }
  end

  def fetch_models_list
    gateway_client.models_list
  rescue StandardError
    {}
  end

  def extract_providers(config)
    return [] if config.nil? || config["error"].present? || config[:error].present?

    providers_cfg = config.dig("models", "providers") || config.dig(:models, :providers) || {}
    result = []

    providers_cfg.each do |id, cfg|
      next unless cfg.is_a?(Hash)
      models = cfg["models"] || cfg[:models] || {}
      result << {
        id: id,
        base_url: cfg["baseUrl"] || cfg[:base_url] || "",
        has_api_key: cfg["apiKey"].present? || cfg[:api_key].present?,
        headers: cfg["headers"] || {},
        models: models.map { |mid, mcfg|
          mcfg = mcfg.is_a?(Hash) ? mcfg : {}
          {
            id: mid,
            cost_per_1k_input: mcfg["costPer1kInput"] || mcfg["inputCost"],
            cost_per_1k_output: mcfg["costPer1kOutput"] || mcfg["outputCost"],
            context_window: mcfg["contextWindow"] || mcfg["context"],
            capabilities: Array(mcfg["capabilities"] || [])
          }
        }
      }
    end

    result
  end

  def build_provider_patch(provider_id)
    pp = params.permit(:base_url, :api_key, headers: {})
    provider_patch = {}
    provider_patch[:baseUrl] = pp[:base_url] if pp[:base_url].present?
    provider_patch[:apiKey] = pp[:api_key] if pp[:api_key].present?
    provider_patch[:headers] = pp[:headers].to_h if pp[:headers].present?

    { models: { providers: { provider_id => provider_patch } } }
  end
end
