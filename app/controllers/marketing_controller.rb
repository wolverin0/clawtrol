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
    prompt = params[:prompt].to_s.strip
    model = params[:model] || "gpt-image-1"
    product = sanitize_filename_component(params[:product].to_s.presence || "futura")
    template = params[:template] || "none"
    size = params[:size] || "1024x1024"
    variant_seed = params[:variant_seed].to_i # For generating variants with slight differences

    if prompt.blank?
      render json: { error: "Prompt cannot be blank" }, status: :unprocessable_entity
      return
    end

    unless model == "gpt-image-1"
      render json: { error: "Model '#{model}' is not supported" }, status: :unprocessable_entity
      return
    end

    product_context = PRODUCT_CONTEXTS[product] || PRODUCT_CONTEXTS["futura"]
    template_style = TEMPLATE_STYLES[template]

    # Combine context + user prompt + template style
    prompt_parts = [product_context, prompt]
    prompt_parts << "Style: #{template_style}" if template_style.present?

    # Add subtle variation for variant generation
    if variant_seed > 0
      variations = ["with dynamic composition", "with creative angle", "with alternative lighting", "with fresh perspective"]
      prompt_parts << variations[variant_seed % variations.length]
    end

    full_prompt = prompt_parts.join(". ")

    begin
      # Call OpenAI gpt-image-1 API
      uri = URI("https://api.openai.com/v1/images/generations")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 120
      http.open_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{OPENAI_API_KEY}"

      request.body = {
        model: "gpt-image-1",
        prompt: full_prompt,
        size: size,
        n: 1,
        output_format: "png"
      }.to_json

      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code.to_i != 200
        error_msg = result.dig("error", "message") || "API request failed"
        render json: { error: error_msg }, status: :bad_gateway
        return
      end

      # Get base64 image data (gpt-image-1 returns b64_json by default)
      image_data = result.dig("data", 0, "b64_json")
      image_url = result.dig("data", 0, "url")

      if image_data.nil? && image_url.nil?
        render json: { error: "No image data in response" }, status: :bad_gateway
        return
      end

      # If we got a URL instead of b64, fetch it
      if image_data.nil? && image_url
        image_response = Net::HTTP.get_response(URI(image_url))
        image_data = Base64.strict_encode64(image_response.body)
      end

      # Save the image
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      filename = "#{product}_#{timestamp}.png"

      FileUtils.mkdir_p(PLAYGROUND_OUTPUT_DIR)
      file_path = File.join(PLAYGROUND_OUTPUT_DIR, filename)

      # SECURITY: Verify the resolved file path stays within the output directory
      unless File.expand_path(file_path).start_with?(File.expand_path(PLAYGROUND_OUTPUT_DIR) + "/")
        render json: { error: "Invalid filename" }, status: :unprocessable_entity
        return
      end

      File.open(file_path, "wb") do |f|
        f.write(Base64.decode64(image_data))
      end

      # Update index.json
      update_playground_index(filename, prompt, full_prompt, product, template, model, size)

      # Return the URL that can be served by the existing show action
      serve_url = "/marketing/generated/playground-live/#{filename}"

      render json: {
        success: true,
        url: serve_url,
        filename: filename,
        product: product,
        template: template,
        model: model,
        prompt: prompt,
        full_prompt: full_prompt,
        size: size,
        generated_at: Time.current.iso8601
      }

    rescue Net::ReadTimeout, Net::OpenTimeout => e
      render json: { error: "Request timed out. Please try again." }, status: :gateway_timeout
    rescue JSON::ParserError => e
      render json: { error: "Invalid response from API" }, status: :bad_gateway
    rescue StandardError => e
      Rails.logger.error("Image generation failed: #{e.message}")
      render json: { error: "Generation failed: #{e.message}" }, status: :internal_server_error
    end
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
    raw = path.to_s

    # SECURITY: absolute path check
    return "" if raw.start_with?("/")

    # SECURITY: null byte check
    return "" if raw.include?(0.chr)

    # SECURITY: reject traversal/dot segments in the requested relative path
    parts = raw.split("/")
    return "" if parts.any? { |p| p == ".." || p.start_with?(".") }

    # SECURITY: symlink escape check
    full_path = File.expand_path(File.join(MARKETING_ROOT, raw))
    return "" unless full_path.start_with?(File.expand_path(MARKETING_ROOT))

    raw
  rescue StandardError
    ""
  end

  # Sanitize a single filename component (product name, template name, etc.)
  # to prevent path traversal via user-controlled filename parts.
  # Strips everything except alphanumerics, hyphens, and underscores.
  def sanitize_filename_component(input)
    sanitized = input.to_s.gsub(/[^a-zA-Z0-9\-_]/, "")
    sanitized.presence || "unknown"
  end

  def build_tree(root_path, search_query = "")
    tree = { name: "marketing", path: "", type: :directory, children: [] }

    return tree unless Dir.exist?(root_path)

    entries = Dir.glob("#{root_path}/**/*", File::FNM_DOTMATCH).reject { |f| File.basename(f).start_with?(".") }

    entries.each do |full_path|
      relative = full_path.sub("#{root_path}/", "")
      next if search_query.present? && !relative.downcase.include?(search_query.downcase)

      parts = relative.split("/")
      insert_into_tree(tree, parts, File.directory?(full_path), relative)
    end

    sort_tree(tree)
    tree
  end

  def insert_into_tree(tree, parts, is_dir, full_relative_path)
    current = tree

    parts.each_with_index do |part, index|
      is_last = index == parts.length - 1
      existing = current[:children].find { |c| c[:name] == part }

      if existing
        current = existing
      else
        node = {
          name: part,
          path: parts[0..index].join("/"),
          type: is_last && !is_dir ? :file : :directory,
          children: []
        }
        node[:extension] = File.extname(part).downcase if node[:type] == :file
        current[:children] << node
        current = node
      end
    end
  end

  def sort_tree(node)
    return unless node[:children]

    node[:children].sort_by! { |c| [c[:type] == :directory ? 0 : 1, c[:name].downcase] }
    node[:children].each { |c| sort_tree(c) }
  end

  def viewable?(ext)
    VIEWABLE_EXTENSIONS.include?(ext)
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
    content
  end

  def mime_type_for(ext)
    {
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".gif" => "image/gif",
      ".webp" => "image/webp",
      ".svg" => "image/svg+xml",
      ".mp4" => "video/mp4",
      ".webm" => "video/webm",
      ".mov" => "video/quicktime",
      ".avi" => "video/x-msvideo"
    }[ext] || "application/octet-stream"
  end

  def build_batch_data(batch_name, batch_path)
    index_path = File.join(batch_path, "index.json")

    if File.exist?(index_path)
      parse_index_json(batch_name, batch_path, index_path)
    else
      scan_media_files(batch_path, batch_name)
    end
  end

  def parse_index_json(batch_name, batch_path, index_path)
    content = JSON.parse(File.read(index_path))
    generated_at = content["generated_at"] || File.mtime(index_path).iso8601

    images = (content["images"] || []).map do |img|
      {
        product: normalize_product(img["product"]),
        type: img["type"] || "unknown",
        filename: img["filename"],
        dimensions: img["dimensions"],
        prompt: img["prompt"],
        url: "/marketing/generated/#{batch_name}/#{img["filename"]}"
      }
    end

    {
      name: batch_name,
      generated_at: generated_at,
      images: images
    }
  rescue JSON::ParserError
    scan_media_files(batch_path, batch_name)
  end

  def scan_media_files(dir_path, batch_name)
    images = []
    generated_at = nil

    Dir.glob(File.join(dir_path, "*")).each do |file_path|
      next unless File.file?(file_path)

      ext = File.extname(file_path).downcase
      next unless MEDIA_EXTENSIONS.include?(ext)

      # Skip very small files (likely corrupt)
      next if File.size(file_path) < 100

      filename = File.basename(file_path)
      mtime = File.mtime(file_path)
      generated_at ||= mtime.iso8601
      generated_at = mtime.iso8601 if mtime.iso8601 > generated_at

      # Try to infer product from filename
      product = infer_product(filename)
      type = infer_type(filename, ext)

      relative_path = if batch_name == "loose-files"
                        "generated/#{filename}"
      else
                        "generated/#{batch_name}/#{filename}"
      end

      images << {
        product: product,
        type: type,
        filename: filename,
        dimensions: nil,
        prompt: nil,
        url: "/marketing/#{relative_path}"
      }
    end

    {
      name: batch_name,
      generated_at: generated_at || Time.current.iso8601,
      images: images
    }
  end

  def normalize_product(product)
    return "unknown" if product.blank?

    case product.to_s.downcase
    when /futura\s*crm/, /crm/
      "futuracrm"
    when /futura\s*fitness/, /fitness/
      "futurafitness"
    when /optima\s*delivery/, /delivery/
      "optimadelivery"
    when /futura/, /brand/
      "futura"
    else
      product.to_s.downcase.gsub(/\s+/, "")
    end
  end

  def infer_product(filename)
    name = filename.downcase
    case name
    when /crm/, /futuracrm/
      "futuracrm"
    when /fitness/, /futurafitness/
      "futurafitness"
    when /delivery/, /optima/
      "optimadelivery"
    when /futura/, /brand/
      "futura"
    else
      "unknown"
    end
  end

  def infer_type(filename, ext)
    name = filename.downcase
    return "video" if VIDEO_EXTENSIONS.include?(ext)

    case name
    when /hero/
      "hero"
    when /instagram|insta|ig/
      "instagram"
    when /story|stories/
      "story"
    when /facebook|fb/
      "facebook"
    when /feature/
      "feature"
    when /post/
      "instagram"
    when /mobile/
      "story"
    when /desktop/
      "hero"
    else
      "image"
    end
  end

  def update_playground_index(filename, user_prompt, full_prompt, product, template, model, size)
    index_path = File.join(PLAYGROUND_OUTPUT_DIR, "index.json")

    # Load existing or create new
    if File.exist?(index_path)
      index_data = JSON.parse(File.read(index_path))
    else
      index_data = { "generated_at" => Time.current.iso8601, "images" => [] }
    end

    # Parse dimensions from size
    dimensions = size

    # Add new entry
    index_data["images"] ||= []
    index_data["images"] << {
      "filename" => filename,
      "product" => product,
      "template" => template,
      "model" => model,
      "type" => infer_type_from_size(size),
      "dimensions" => dimensions,
      "prompt" => user_prompt,
      "full_prompt" => full_prompt,
      "generated_at" => Time.current.iso8601
    }

    # Update batch timestamp
    index_data["generated_at"] = Time.current.iso8601

    # Atomic write to prevent corruption on crash
    require "tempfile"
    tmp = Tempfile.new("index.json", File.dirname(index_path))
    begin
      tmp.write(JSON.pretty_generate(index_data))
      tmp.close
      File.rename(tmp.path, index_path)
    rescue StandardError
      tmp.close!
      raise
    end
  end

  def infer_type_from_size(size)
    case size
    when "1080x1080", "1024x1024"
      "instagram"
    when "1200x630"
      "facebook"
    when "1080x1920"
      "story"
    else
      "image"
    end
  end
end
