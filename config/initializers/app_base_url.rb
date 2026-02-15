# config/initializers/app_base_url.rb
Rails.application.config.app_base_url = ENV.fetch("APP_BASE_URL", "http://localhost:#{ENV.fetch('PORT', '4001')}")

if ENV["APP_BASE_URL"].blank?
  Rails.logger.warn "[Config] APP_BASE_URL not set — defaulting to #{Rails.application.config.app_base_url}. Set APP_BASE_URL for production."
end
