# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      # Include session support for browser-based API calls (agent_log)
      include ActionController::Cookies
      include ActionController::RequestForgeryProtection

      include Api::TokenAuthentication
      include Api::RateLimitable

      # Default rate limit: 120 requests per minute per user/IP
      before_action -> { rate_limit!(limit: 120, window: 60) }

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from ArgumentError, with: :bad_argument

      private

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: "Missing parameter: #{exception.param}" }, status: :bad_request
      end

      def bad_argument(exception)
        Rails.logger.warn("[API] ArgumentError: #{exception.message}")
        render json: { error: "Invalid argument" }, status: :bad_request
      end
    end
  end
end
