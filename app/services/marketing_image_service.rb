# frozen_string_literal: true

# Service for generating marketing images via OpenAI API.
#
# Usage:
#   result = MarketingImageService.call(
#     prompt: "A modern CRM dashboard",
#     product: "futuracrm",
#     template: "ad-creative",
#     size: "1024x1024"
#   )
#   # => { success: true, image_url: "...", revised_prompt: "..." }
class MarketingImageService
  PRODUCT_CONTEXTS = {
    "futuracrm" => "For FuturaCRM, a modern CRM platform for Argentine SMBs",
    "futurafitness" => "For FuturaFitness, a gym management and fitness tracking app",
    "optimadelivery" => "For OptimaDelivery, a last-mile delivery optimization platform",
    "futura" => "For Futura Sistemas, a tech company building software solutions"
  }.freeze

  TEMPLATE_STYLES = {
    "ad-creative" => "Social media advertisement style, bold vibrant colors, eye-catching design, clear call-to-action text overlay, marketing focused, professional product photography",
    "carousel-slide" => "Clean minimal design, ample white space, single key message, modern typography, suitable for carousel format, consistent branding",
    "lifestyle-shot" => "Product in real-world context, natural lighting, aspirational lifestyle setting, people using the product naturally, authentic and relatable",
    "background-swap" => "Product isolated on creative background, multiple background options, studio quality, clean product cutout, various scene settings",
    "feature-highlight" => "Product screenshot with feature callouts, annotated interface, highlighting key features, clean UI presentation, explanatory overlays"
  }.freeze

  VALID_SIZES = %w[1024x1024 1792x1024 1024x1792].freeze

  def self.call(prompt:, product: "futura", template: "none", size: "1024x1024", variant_seed: nil)
    new(prompt: prompt, product: product, template: template, size: size, variant_seed: variant_seed).call
  end

  def initialize(prompt:, product:, template:, size:, variant_seed: nil)
    @prompt = prompt.to_s.strip
    @product = product.to_s.downcase.presence || "futura"
    @template = template.to_s.downcase.presence || "none"
    @size = size.presence || "1024x1024"
    @variant_seed = variant_seed
  end

  def call
    return failure("Prompt is required") if @prompt.blank?

    # Validate size
    return failure("Invalid size. Valid options: #{VALID_SIZES.join(', ')}") unless valid_size?

    # Build full prompt
    full_prompt = build_full_prompt

    # Call OpenAI API
    response = fetch_image_from_openai(full_prompt)

    if response.success?
      success(response.data.first)
    else
      failure(response.error)
    end
  end

  private

  def valid_size?
    VALID_SIZES.include?(@size)
  end

  def build_full_prompt
    prompt_parts = []

    # Add product context
    product_context = PRODUCT_CONTEXTS[@product] || PRODUCT_CONTEXTS["futura"]
    prompt_parts << product_context

    # Add user prompt
    prompt_parts << @prompt

    # Add template style
    template_style = TEMPLATE_STYLES[@template]
    prompt_parts << "Style: #{template_style}" if template_style.present?

    # Add variant variation if seed provided
    if @variant_seed.to_i > 0
      variations = ["with dynamic composition", "with creative angle", "with alternative lighting", "with fresh perspective"]
      prompt_parts << variations[@variant_seed % variations.length]
    end

    prompt_parts.join(". ")
  end

  def fetch_image_from_openai(prompt)
    uri = URI("https://api.openai.com/v1/images/generations")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{api_key}"

    request.body = {
      model: "gpt-image-1",
      prompt: prompt,
      size: @size,
      n: 1,
      output_format: "png"
    }.to_json

    begin
      response = http.request(request)
      json = JSON.parse(response.body)

      if response.code.to_i == 200 && json["data"]
        OpenStruct.new(success: true, data: json["data"], error: nil)
      else
        error_msg = json.dig("error", "message") || "Unknown error"
        OpenStruct.new(success: false, data: nil, error: error_msg)
      end
    rescue Net::OpenTimeout
      OpenStruct.new(success: false, data: nil, error: "Request timed out")
    rescue JSON::ParserError
      OpenStruct.new(success: false, data: nil, error: "Invalid JSON response")
    rescue StandardError => e
      OpenStruct.new(success: false, data: nil, error: e.message)
    end
  end

  def api_key
    ENV.fetch("OPENAI_API_KEY", "")
  end

  def success(data)
    {
      success: true,
      image_url: data.dig("url"),
      revised_prompt: data.dig("revised_prompt")
    }
  end

  def failure(error_message)
    { success: false, error: error_message }
  end
end
