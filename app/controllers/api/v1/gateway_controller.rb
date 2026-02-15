# frozen_string_literal: true

module Api
  module V1
    class GatewayController < BaseController
      include GatewayClientAccessible

      # GET /api/v1/gateway/health
      def health
        result = Rails.cache.fetch("gateway/health/#{current_user.id}", expires_in: 15.seconds) do
          gateway_client.health
        end
        render json: result
      end

      # GET /api/v1/gateway/channels
      def channels
        result = Rails.cache.fetch("gateway/channels/#{current_user.id}", expires_in: 30.seconds) do
          gateway_client.channels_status
        end
        render json: result
      end

      # GET /api/v1/gateway/cost
      def cost
        result = Rails.cache.fetch("gateway/cost/#{current_user.id}", expires_in: 60.seconds) do
          gateway_client.usage_cost
        end
        render json: result
      end

      # GET /api/v1/gateway/models
      def models
        result = Rails.cache.fetch("gateway/models/#{current_user.id}", expires_in: 5.minutes) do
          gateway_client.models_list
        end
        render json: result
      end

      # GET /api/v1/gateway/nodes
      def nodes_status
        result = Rails.cache.fetch("gateway/nodes/#{current_user.id}", expires_in: 15.seconds) do
          gateway_client.nodes_status
        end
        render json: result
      end

      # GET /api/v1/gateway/plugins
      def plugins
        result = Rails.cache.fetch("gateway/plugins/#{current_user.id}", expires_in: 2.minutes) do
          gateway_client.plugins_status
        end
        render json: result
      end
    end
  end
end
