# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "fileutils"

class MarketingController < ApplicationController
  include MarkdownSanitizationHelper
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

  private

  def save_generated_image(image_url, product)
    return failure("No image URL in response") if image_url.blank?

    # Fetch image data (URL or base64)
    image_data = fetch_image_data(image_url)
    return image_data unless image_data[:success]

    # Save the image
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "#{product}_#{timestamp}.png"

    FileUtils.mkdir_p(PLAYGROUND_OUTPUT_DIR)
    file_path = File.join(PLAYGROUND_OUTPUT_DIR, filename)

    # SECURITY: Verify the resolved file path stays within the output directory
    unless File.expand_path(file_path).start_with?(File.expand_path(PLAYGROUND_OUTPUT_DIR) + "/")
      return failure("Invalid filename")
    end

    File.open(file_path, "wb") { |f| f.write(Base64.decode64(image_data[:data])) }

    { success: true, filename: filename, serve_url: "/marketing/generated/playground-live/#{filename}" }
  rescue StandardError => e
    failure("Failed to save image: #{e.message}")
  end

  def fetch_image_data(image_url)
    # If it's a data URL or base64, decode directly
    if image_url.start_with?("data:")
      # Extract base64 from data URL
      match = image_url.match(/data:image\/\w+;base64,(.+)/)
      return { success: true, data: match[1] } if match
      return failure("Invalid data URL format")
    end

    # If it's a URL, fetch it
    begin
      response = Net::HTTP.get_response(URI(image_url))
      if response.code.to_i == 200
        { success: true, data: Base64.strict_encode64(response.body) }
      else
        failure("Failed to fetch image: HTTP #{response.code}")
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      failure("Request timed out")
    rescue StandardError => e
      failure("Failed to fetch image: #{e.message}")
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

    @file_path = File.join(MARKETING_ROOT, relative_path)

    unless File.exist?(@file_path) && File.file?(@file_path)
      render plain: "File not found", status: :not_found
      return
    end

    # SECURITY: Resolve symlinks and verify final path is still within MARKETING_ROOT.
    # Without this, a symlink under marketing/ could point anywhere on the filesystem.
    real_path = File.realpath(@file_path)
    real_root = File.realpath(MARKETING_ROOT)
    unless real_path.start_with?(real_root + "/")
      Rails.logger.warn("[MarketingController] Path escaped root via symlink: #{@file_path} -> #{real_path}")
      render plain: "File not found", status: :not_found
      return
    end

    @relative_path = relative_path
    @extension = File.extname(@file_path).downcase
    @filename = File.basename(@file_path)

    # Serve media files directly (images, videos)
    if MEDIA_EXTENSIONS.include?(@extension)
      send_file real_path, type: mime_type_for(@extension), disposition: :inline
      return
    end

    if viewable?(@extension)
      @content = File.read(real_path, encoding: "UTF-8")
      @rendered_content = render_content(@content, @extension)
    else
      @is_binary = true
    end
  end

  private

  def sanitize_path(path)
    # Prevent directory traversal and file disclosure attacks.
    # This is critical because `show` is unauthenticated.
    return "" if path.blank?

    cleaned = path.to_s

    # SECURITY: Reject null bytes (can truncate paths in C-based libs)
    return "" if cleaned.include?("\x00")

    # Normalize backslashes to forward slashes
    cleaned = cleaned.gsub("\\", "/")

    # SECURITY: Reject path traversal sequences (literal and url-encoded)
    return "" if cleaned.include?("..")

    # Remove leading slashes
    cleaned = cleaned.sub(%r{^/+}, "")

    # SECURITY: Block dotfiles and dotdirs — any component starting with '.'
    # Prevents access to .env, .git, .gitignore, .DS_Store etc.
    components = cleaned.split("/")
    return "" if components.any? { |c| c.start_with?(".") }

    # SECURITY: Reject empty components (double slashes) which could confuse path resolution
    return "" if components.any?(&:blank?)

    cleaned
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
    when ".html"
      content # Render as-is (will be escaped in view)
    else
      content
    end
  end

  def render_markdown(content)
    # Use shared helper for XSS-safe markdown rendering
    safe_markdown(content)
  end

  def render_json(content)
    JSON.pretty_generate(JSON.parse(content))
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

    File.write(index_path, JSON.pretty_generate(index_data))
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
