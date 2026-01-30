# Configure Resend API key for sending emails
# Get your API key from https://resend.com/api-keys
if Rails.application.credentials.dig(:resend, :api_key).present?
  Resend.api_key = Rails.application.credentials.dig(:resend, :api_key)
else
  Rails.logger.warn("Resend API key not configured in credentials") if Rails.env.production?
end
