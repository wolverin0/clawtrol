class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :openclaw_memory_health

  def openclaw_memory_health
    return nil unless current_user

    @openclaw_memory_health ||= OpenclawMemorySearchHealthService.new(current_user).call
  end
end
