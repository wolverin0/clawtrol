# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "fileutils"

class MarketingController < ApplicationController
  include MarkdownSanitizationHelper
  include MarketingTreeBuilder
  include MarketingContentManagement

  MARKETING_ROOT = Rails.root.join("..", ".openclaw", "workspace", "marketing").to_s.freeze
  VIEWABLE_EXTENSIONS = %w[.md .json .html .txt .yml .yaml].freeze
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg].freeze
  VIDEO_EXTENSIONS = %w[.mp4 .webm .mov .avi].freeze
  MEDIA_EXTENSIONS = IMAGE_EXTENSIONS + VIDEO_EXTENSIONS

  OPENAI_API_KEY = ENV.fetch("OPENAI_API_KEY", "")
  PLAYGROUND_OUTPUT_DIR = File.expand_path("~/.openclaw/workspace/marketing/generated/playground-live").freeze

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

  N8N_WEBHOOK_URL = ENV.fetch("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/social-media-post").freeze

  skip_before_action :require_authentication, only: [:index, :show, :playground, :generated_content]

  def index
    @search_query = params[:q].to_s.strip
    @tree = build_tree(MARKETING_ROOT, @search_query)
  end

  def playground
    # Social Media Studio - all client-side
  end

  def generate_image
    model = params[:model].presence || "gpt-image-1"
    unless model == "gpt-image-1"
      render json: { error: "Model '#{model}' is not supported" }, status: :unprocessable_entity
      return
    end

    result = MarketingImageService.call(
      prompt: params[:prompt].to_s.strip,
      product: params[:product].to_s,
      template: params[:template].to_s,
      size: params[:size].to_s,
      variant_seed: params[:variant_seed].to_i
    )

    unless result[:success]
      error = result[:error]
      status = error&.include?("time out") ? :gateway_timeout : :unprocessable_entity
      render json: { error: error }, status: status
      return
    end

    # Save the image to disk
    save_result = save_generated_image(result[:image_url], params[:product].to_s.presence || "futura")

    unless save_result[:success]
      render json: { error: save_result[:error] }, status: :internal_server_error
      return
    end

    # Update index
    update_playground_index(
      save_result[:filename],
      params[:prompt].to_s.strip,
      result[:revised_prompt] || params[:prompt].to_s,
      params[:product].to_s.presence || "futura",
      params[:template].to_s,
      "gpt-image-1",
      params[:size].to_s
    )

    render json: {
      success: true,
      url: save_result[:serve_url],
      filename: save_result[:filename],
      product: params[:product].to_s.presence || "futura",
      template: params[:template].to_s,
      model: "gpt-image-1",
      prompt: params[:prompt].to_s.strip,
      full_prompt: result[:revised_prompt],
      size: params[:size].to_s,
      generated_at: Time.current.iso8601
    }
  rescue StandardError => e
    Rails.logger.error("Image generation failed: #{e.message}")
    render json: { error: "Generation failed: #{e.message}" }, status: :internal_server_error
  end

  def publish_to_n8n
    result = SocialMediaPublisher.call(
      image_url: params[:image_url].to_s.strip,
      caption: params[:caption].to_s.strip,
      hashtags: params[:hashtags] || [],
      platforms: params[:platforms] || { "facebook" => true, "instagram" => true },
      cta: params[:cta].to_s.strip,
      product: params[:product].to_s.strip
    )

    if result[:success]
      render json: result
    else
      render json: result, status: :bad_gateway
    end
  end

  def generated_content
    generated_root = File.join(MARKETING_ROOT, "generated")
    batches = []

    if Dir.exist?(generated_root)
      Dir.children(generated_root).sort.each do |entry|
        full_path = File.join(generated_root, entry)
        next unless File.directory?(full_path)

        batch_data = build_batch_data(entry, full_path)
        batches << batch_data if batch_data[:images].any?
      end

      # Also scan for loose files in generated/ root
      loose_files = scan_media_files(generated_root, "loose-files")
      batches << loose_files if loose_files[:images].any?
    end

    # Sort batches by generated_at (newest first)
    batches.sort_by! { |b| b[:generated_at] || "" }.reverse!

    render json: { batches: batches }
  end

  def show
    relative_path = sanitize_path(params[:path])

    if relative_path.blank?
      render plain: "Invalid path", status: :bad_request
      return
    end

    full_path = File.join(MARKETING_ROOT, relative_path)

    unless File.exist?(full_path)
      render plain: "File not found", status: :not_found
      return
    end

    if File.directory?(full_path)
      @search_query = relative_path.to_s
      @tree = build_tree(MARKETING_ROOT, @search_query)
      render "index"
      return
    end

    ext = File.extname(full_path).downcase

    if image?(ext)
      redirect_to "/marketing/#{relative_path}" and return
    end

    content = File.read(full_path)
    render_content(content, ext)
  end

  private

  # Path sanitization - remains in controller for security critical logic
  def sanitize_path(path)
    # SECURITY: absolute path check
    return "" if path.to_s.start_with?("/")

    # SECURITY: null byte check
    return "" if path.to_s.include?("\0")

    # SECURITY: symlink escape check
    full_path = File.expand_path(File.join(MARKETING_ROOT, path.to_s))
    return "" unless full_path.start_with?(File.expand_path(MARKETING_ROOT))

    # SECURITY: dotfile check - prevent access to hidden files
    parts = path.to_s.split("/")
    return "" if parts.any? { |p| p.start_with?(".") && p != "." && p != ".." }

    path.to_s
  rescue StandardError
    ""
  end

  def sanitize_filename_component(input)
    input.to_s.gsub(/[^a-zA-Z0-9_-]/, "").presence || "unknown"
  end

  def image?(ext)
    IMAGE_EXTENSIONS.include?(ext)
  end

  def render_content(content, extension)
    case extension
    when ".md"
      render_markdown(content)
    when ".json"
      render_json(content)
    when ".html", ".htm"
      render html: content.html_safe
    else
      render plain: content
    end
  end

  def render_markdown(content)
    # Basic markdown rendering
    html = MarkdownSanitizationHelper::KramdownDocument.new(content).to_html
    render html: html.html_safe
  end

  def render_json(content)
    json = JSON.parse(content)
    render json: json
  rescue JSON::ParserError
    render plain: "Invalid JSON", status: :bad_request
  end
end
