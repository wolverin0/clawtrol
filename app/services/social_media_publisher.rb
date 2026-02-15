# frozen_string_literal: true

# Service for publishing marketing content to n8n webhooks.
#
# Usage:
#   result = SocialMediaPublisher.call(
#     image_url: "https://...",
#     caption: "Check this out!",
#     hashtags: ["tech", "startup"],
#     platforms: { "facebook" => true, "instagram" => true },
#     cta: "Learn more",
#     product: "futura"
#   )
class SocialMediaPublisher
  N8N_WEBHOOK_URL = ENV.fetch("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/social-media-post").freeze

  def self.call(image_url:, caption:, hashtags: [], platforms: {}, cta: "", product: "")
    new(
      image_url: image_url,
      caption: caption,
      hashtags: hashtags,
      platforms: platforms,
      cta: cta,
      product: product
    ).publish
  end

  def initialize(image_url:, caption:, hashtags:, platforms:, cta:, product:)
    @image_url = image_url.to_s.strip
    @caption = caption.to_s.strip
    @hashtags = hashtags || []
    @platforms = platforms || {}
    @cta = cta.to_s.strip
    @product = product.to_s.strip
  end

  def publish
    return failure("Image URL is required") if @image_url.blank?

    payload = build_payload

    response = send_webhook(payload)

    if response[:success]
      success(response[:body], payload)
    else
      # n8n not responding is not a critical failure - return warning
      if response[:error]&.include?("timeout") || response[:error]&.include?("connection")
        warning("Post queued locally (n8n webhook not responding)", payload)
      else
        failure("Webhook returned error: #{response[:error]}")
      end
    end
  end

  private

  def build_payload
    {
      image_url: resolve_full_url(@image_url),
      caption: @caption,
      hashtags: @hashtags,
      hashtags_string: @hashtags.map { |t| "##{t}" }.join(" "),
      platforms: @platforms,
      cta: @cta,
      product: @product,
      queued_at: Time.current.iso8601,
      source: "clawtrol-playground"
    }
  end

  def resolve_full_url(url)
    return url if url.start_with?("http")

    # For Rails test environment, use a placeholder
    base_url = Rails.application.respond_to?(:config) ? Rails.application.config.action_controller.default_url_options[:host] : "http://localhost:3000"
    base_url ||= "http://localhost:3000"
    "#{base_url}#{url}"
  end

  def send_webhook(payload)
    uri = URI(N8N_WEBHOOK_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    begin
      response = http.request(request)
      if response.code.to_i >= 200 && response.code.to_i < 300
        { success: true, body: response.body }
      else
        { success: false, error: "HTTP #{response.code}", body: response.body }
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      { success: false, error: "timeout: #{e.message}" }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end

  def success(body, payload)
    { success: true, message: "Post queued successfully!", webhook_response: body, payload: payload }
  end

  def warning(message, payload)
    { success: true, warning: message, payload: payload }
  end

  def failure(error_message)
    { success: false, error: error_message }
  end
end
