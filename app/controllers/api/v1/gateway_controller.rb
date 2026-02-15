# frozen_string_literal: true

module Api
  module V1
    class GatewayController < BaseController
      include GatewayClientAccessible

      # GET /api/v1/gateway/health
      def health
        render json: cached_gateway_call("health", expires_in: 15.seconds) { gateway_client.health }
      end

      # GET /api/v1/gateway/channels
      def channels
        render json: cached_gateway_call("channels", expires_in: 30.seconds) { gateway_client.channels_status }
      end

      # GET /api/v1/gateway/cost
      def cost
        render json: cached_gateway_call("cost", expires_in: 60.seconds) { gateway_client.usage_cost }
      end

      # GET /api/v1/gateway/models
      def models
        render json: cached_gateway_call("models", expires_in: 5.minutes) { gateway_client.models_list }
      end

      # GET /api/v1/gateway/nodes
      def nodes_status
        render json: cached_gateway_call("nodes", expires_in: 15.seconds) { gateway_client.nodes_status }
      end

      # GET /api/v1/gateway/plugins
      def plugins
        render json: cached_gateway_call("plugins", expires_in: 2.minutes) { gateway_client.plugins_status }
      end

      private

      # Cache gateway responses but skip caching error results.
      # This prevents transient gateway failures (timeout, connection refused)
      # from being cached and served stale for the full TTL.
      def cached_gateway_call(key, expires_in:)
        cache_key = "gateway/#{key}/#{current_user.id}"
        cached = Rails.cache.read(cache_key)
        return cached if cached && !gateway_error?(cached)

        result = yield
        Rails.cache.write(cache_key, result, expires_in: expires_in) unless gateway_error?(result)
        result
      end

      def gateway_error?(result)
        result.is_a?(Hash) && result["error"].present?
      end
    end
  end
end
