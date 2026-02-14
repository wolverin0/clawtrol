module Api
  module V1
    class GatewayController < BaseController
      # GET /api/v1/gateway/health
      def health
        client = OpenclawGatewayClient.new(current_user)
        result = Rails.cache.fetch("gateway/health/#{current_user.id}", expires_in: 15.seconds) do
          client.health
        end
        render json: result
      end

      # GET /api/v1/gateway/channels
      def channels
        client = OpenclawGatewayClient.new(current_user)
        result = Rails.cache.fetch("gateway/channels/#{current_user.id}", expires_in: 30.seconds) do
          client.channels_status
        end
        render json: result
      end

      # GET /api/v1/gateway/cost
      def cost
        client = OpenclawGatewayClient.new(current_user)
        result = Rails.cache.fetch("gateway/cost/#{current_user.id}", expires_in: 60.seconds) do
          client.usage_cost
        end
        render json: result
      end

      # GET /api/v1/gateway/models
      def models
        client = OpenclawGatewayClient.new(current_user)
        result = Rails.cache.fetch("gateway/models/#{current_user.id}", expires_in: 5.minutes) do
          client.models_list
        end
        render json: result
      end
    end
  end
end
