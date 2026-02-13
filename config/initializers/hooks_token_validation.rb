Rails.application.config.after_initialize do
  hooks_token = ENV["HOOKS_TOKEN"].to_s.strip
  if Rails.env.production? && hooks_token.blank?
    Rails.logger.warn("[SECURITY] HOOKS_TOKEN environment variable is not set in production!")
  end
end
