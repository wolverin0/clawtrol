# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Global error handling for HTML controllers.
  # Prevents 500 errors on missing records and invalid parameters.
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::StaleObjectError, with: :render_conflict
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  # Defense-in-depth security headers (supplement nginx config).
  # These apply even when accessing Puma directly (dev/staging).
  after_action :set_security_headers

  helper_method :openclaw_memory_health

  def openclaw_memory_health
    return nil unless current_user

    @openclaw_memory_health ||= OpenclawMemorySearchHealthService.new(current_user).call
  end

  private

  def render_not_found
    respond_to do |format|
      format.html { render file: Rails.public_path.join("404.html"), layout: false, status: :not_found }
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.turbo_stream { head :not_found }
    end
  end

  def render_conflict(_exception)
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: "This record was modified by another request. Please try again." }
      format.json { render json: { error: "Resource was modified by another request" }, status: :conflict }
      format.turbo_stream { head :conflict }
    end
  end

  def render_bad_request(exception)
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: "Missing parameter: #{exception.param}" }
      format.json { render json: { error: "Missing parameter: #{exception.param}" }, status: :bad_request }
      format.turbo_stream { head :bad_request }
    end
  end

  def set_security_headers
    response.headers["X-Content-Type-Options"] ||= "nosniff"
    response.headers["X-Frame-Options"] ||= "SAMEORIGIN"
    response.headers["Referrer-Policy"] ||= "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] ||= "camera=(), microphone=(), geolocation=()"
    response.headers["X-Permitted-Cross-Domain-Policies"] ||= "none"
  end
end
