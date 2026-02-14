class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Defense-in-depth security headers (supplement nginx config).
  # These apply even when accessing Puma directly (dev/staging).
  after_action :set_security_headers

  helper_method :openclaw_memory_health

  def openclaw_memory_health
    return nil unless current_user

    @openclaw_memory_health ||= OpenclawMemorySearchHealthService.new(current_user).call
  end

  private

  def set_security_headers
    response.headers["X-Content-Type-Options"] ||= "nosniff"
    response.headers["X-Frame-Options"] ||= "SAMEORIGIN"
    response.headers["Referrer-Policy"] ||= "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] ||= "camera=(), microphone=(), geolocation=()"
    response.headers["X-Permitted-Cross-Domain-Policies"] ||= "none"
  end
end
