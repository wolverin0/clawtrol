# frozen_string_literal: true

module Api
  module HookAuthentication
    extend ActiveSupport::Concern

    private

    # Authenticates requests using X-Hook-Token header.
    # Uses constant-time comparison to prevent timing attacks.
    # Returns true if authenticated, renders 401 and returns false otherwise.
    def authenticate_hook_token!
      token = request.headers["X-Hook-Token"].to_s
      configured_token = Rails.application.config.hooks_token.to_s

      unless configured_token.present? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, configured_token)
        render json: { error: "unauthorized" }, status: :unauthorized
        return false
      end

      true
    end
  end
end
