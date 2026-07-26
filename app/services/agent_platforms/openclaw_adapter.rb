# frozen_string_literal: true

module AgentPlatforms
  # Adapter that exposes existing OpenClaw services through the AgentPlatform
  # capability contract. This is intentionally a thin wrapper:
  #   - OpenclawGatewayClient still implements the HTTP behavior
  #   - OpenclawModelsService still owns CLI model discovery
  # The adapter normalizes their return values into Result objects so callers
  # don't have to know which backend produced them.
  class OpenclawAdapter < BaseAdapter
    def key = "openclaw"
    def label = "OpenClaw"

    def available?
      user.openclaw_gateway_url.present? && user.openclaw_gateway_token.present?
    end

    def health
      data = gateway_client.health
      if data.is_a?(Hash) && data["error"].present?
        Result.offline(data["error"], platform: key, data: data)
      else
        Result.ok(data, platform: key)
      end
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def sessions_list
      data = gateway_client.sessions_list
      err = data.is_a?(Hash) ? data["error"] : nil
      err ? Result.offline(err, platform: key, data: data) : Result.ok(data, platform: key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def session_detail(session_key)
      data = gateway_client.session_detail(session_key)
      err = data.is_a?(Hash) ? data["error"] : nil
      err ? Result.error(err, platform: self.key, data: data) : Result.ok(data, platform: self.key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def spawn_session!(model:, prompt:)
      Result.ok(gateway_client.spawn_session!(model: model, prompt: prompt), platform: key)
    rescue StandardError => e
      Result.error(e.message, platform: key)
    end

    def sessions_send(session_key, message)
      Result.ok(gateway_client.sessions_send(session_key, message), platform: key)
    rescue StandardError => e
      Result.error(e.message, platform: key)
    end

    def sessions_history(session_key, limit: 20)
      Result.ok(gateway_client.sessions_history(session_key, limit: limit), platform: key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def cron_list(all: true)
      data = gateway_client.cron_list
      err = data.is_a?(Hash) ? data["error"] : nil
      err ? Result.offline(err, platform: key, data: data) : Result.ok(data, platform: key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def cron_create(params) = wrap { gateway_client.cron_create(params) }
    def cron_update(id, params) = wrap { gateway_client.cron_update(id, params) }
    def cron_delete(id) = wrap { gateway_client.cron_delete(id) }
    def cron_pause(id) = wrap { gateway_client.cron_disable(id) }
    def cron_resume(id) = wrap { gateway_client.cron_enable(id) }
    def cron_run(id) = wrap { gateway_client.cron_run(id) }

    def models_list
      providers = OpenclawModelsService.providers_with_models
      Result.ok({ "providers" => providers }, platform: key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def current_model
      data = gateway_client.health
      Result.ok({ "model" => data["model"], "provider" => data["provider"] }, platform: key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def config_get
      Result.ok(gateway_client.config_get, platform: key)
    rescue StandardError => e
      Result.offline(e.message, platform: key)
    end

    def file_roots
      { "openclaw" => Pathname.new(File.expand_path(ENV["CLAWTROL_WORKSPACE_DIR"].presence || "~/.openclaw/workspace")) }
    end

    private

    def gateway_client
      @gateway_client ||= OpenclawGatewayClient.new(user)
    end

    def wrap
      data = yield
      err = data.is_a?(Hash) ? data["error"] : nil
      err ? Result.error(err, platform: key, data: data) : Result.ok(data, platform: key)
    rescue StandardError => e
      Result.error(e.message, platform: key)
    end
  end
end
