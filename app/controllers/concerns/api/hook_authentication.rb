# frozen_string_literal: true

module Api
  module HookAuthentication
    extend ActiveSupport::Concern

    private

    # Legacy hook authentication exists only to exercise retired-route tests.
    # Production requests are also stopped by SafeLan::LegacyExecutionBlocker,
    # and this concern fails closed if the middleware is ever bypassed.
    def authenticate_hook_token!
      unless Rails.env.test? && ENV["CLAWTROL_TEST_LEGACY_EXECUTION"] == "1"
        render json: { error: "legacy executor retired" }, status: :gone
        return false
      end

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
