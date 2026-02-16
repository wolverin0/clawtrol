# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "fileutils"

module MarketingContentManagement
  extend ActiveSupport::Concern

  included do
    MARKETING_ROOT = Rails.root.join("..", ".openclaw", "workspace", "marketing").to_s.freeze
    VIEWABLE_EXTENSIONS = %w[.md .json .html .txt .yml .yaml].freeze
    IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg].freeze
    VIDEO_EXTENSIONS = %w[.mp4 .webm .mov .avi].freeze
    MEDIA_EXTENSIONS = IMAGE_EXTENSIONS + VIDEO_EXTENSIONS
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
  end

  # Image saving - extracted from MarketingController#save_generated_image
  def save_generated_image(image_url, product)
    return failure("No image URL in response") if image_url.blank?

    image_data = fetch_image_data(image_url)
    return image_data unless image_data[:success]

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "#{product}_#{timestamp}.png"

    FileUtils.mkdir_p(PLAYGROUND_OUTPUT_DIR)
    file_path = File.join(PLAYGROUND_OUTPUT_DIR, filename)

    unless File.expand_path(file_path).start_with?(File.expand_path(PLAYGROUND_OUTPUT_DIR) + "/")
      return failure("Invalid filename")
    end

    File.open(file_path, "wb") { |f| f.write(Base64.decode64(image_data[:data])) }

    { success: true, filename: filename, serve_url: "/marketing/generated/playground-live/#{filename}" }
  rescue StandardError => e
    failure("Failed to save image: #{e.message}")
  end

  # Image fetching - extracted from MarketingController#fetch_image_data
  def fetch_image_data(image_url)
    if image_url.start_with?("data:")
      match = image_url.match(/data:image\/\w+;base64,(.+)/)
      return { success: true, data: match[1] } if match
      return failure("Invalid data URL format")
    end

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

  # Batch data building - extracted from MarketingController#build_batch_data
  def build_batch_data(batch_name, batch_path)
    index_path = File.join(batch_path, "index.json")
    index_data = if File.exist?(index_path)
      JSON.parse(File.read(index_path))
    else
      { "generated_at" => Time.current.iso8601, "images" => [] }
    end

    images = []
    Dir.children(batch_path).sort.each do |file|
      next unless IMAGE_EXTENSIONS.include?(File.extname(file).downcase)

      full_path = File.join(batch_path, file)
      stat = File.stat(full_path)
      image_entry = {
        "filename" => file,
        "path" => "/marketing/generated/#{batch_name}/#{file}",
        "size" => stat.size,
        "modified" => stat.mtime.iso8601
      }

      # Enrich with metadata if available
      image_meta = index_data["images"]&.find { |i| i["filename"] == file }
      image_entry.merge!(image_meta) if image_meta

      images << image_entry
    end

    {
      batch: batch_name,
      path: "/marketing/generated/#{batch_name}",
      images: images,
      generated_at: index_data["generated_at"]
    }
  end

  # Parse index JSON - extracted from MarketingController#parse_index_json
  def parse_index_json(batch_name, batch_path, index_path)
    if File.exist?(index_path)
      JSON.parse(File.read(index_path))
    else
      { "generated_at" => Time.current.iso8601, "images" => [] }
    end
  end

  # Scan media files - extracted from MarketingController#scan_media_files
  def scan_media_files(dir_path, batch_name)
    images = []
    Dir.children(dir_path).sort.each do |file|
      next unless IMAGE_EXTENSIONS.include?(File.extname(file).downcase)

      full_path = File.join(dir_path, file)
      next unless File.file?(full_path)

      stat = File.stat(full_path)
      images << {
        "filename" => file,
        "path" => "/marketing/generated/#{batch_name}/#{file}",
        "size" => stat.size,
        "modified" => stat.mtime.iso8601
      }
    end

    {
      batch: batch_name,
      path: "/marketing/generated/#{batch_name}",
      images: images,
      generated_at: Time.current.iso8601
    }
  end

  # Normalize product name - extracted from MarketingController#normalize_product
  def normalize_product(product)
    return "futura" if product.blank?

    product.downcase.gsub(/[^a-z0-9]/, "").presence || "futura"
  end

  # Infer product from filename - extracted from MarketingController#infer_product
  def infer_product(filename)
    return nil if filename.blank?

    basename = File.basename(filename, ".*").downcase
    PRODUCT_CONTEXTS.keys.find { |k| basename.include?(k) }
  end

  # Infer type from filename - extracted from MarketingController#infer_type
  def infer_type(filename, ext)
    return "unknown" if filename.blank?

    name = filename.downcase
    return "video" if VIDEO_EXTENSIONS.include?(ext)
    return "image" if IMAGE_EXTENSIONS.include?(ext)

    case name
    when /instagram/, /ig_/
      "instagram"
    when /facebook/, /fb_/
      "facebook"
    when /twitter/, /x_/, /tweet/
      "twitter"
    when /linkedin/
      "linkedin"
    when /\.md$/
      "markdown"
    when /\.json$/
      "json"
    when /\.html?$/
      "html"
    else
      "file"
    end
  end

  # Update playground index - extracted from MarketingController#update_playground_index
  def update_playground_index(filename, user_prompt, full_prompt, product, template, model, size)
    batch_name = normalize_product(product)
    batch_path = File.join(PLAYGROUND_OUTPUT_DIR, batch_name)
    index_path = File.join(batch_path, "index.json")

    FileUtils.mkdir_p(batch_path)

    index_data = if File.exist?(index_path)
      JSON.parse(File.read(index_path))
    else
      { "generated_at" => Time.current.iso8601, "images" => [] }
    end

    dimensions = size
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

    index_data["generated_at"] = Time.current.iso8601

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

  # Infer type from size - extracted from MarketingController#infer_type_from_size
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

  # MIME type detection - extracted from MarketingController#mime_type_for
  def mime_type_for(ext)
    case ext.downcase
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".gif" then "image/gif"
    when ".webp" then "image/webp"
    when ".svg" then "image/svg+xml"
    when ".mp4" then "video/mp4"
    when ".webm" then "video/webm"
    when ".mov" then "video/quicktime"
    when ".avi" then "video/x-msvideo"
    when ".md" then "text/markdown"
    when ".json" then "application/json"
    when ".html", ".htm" then "text/html"
    when ".txt" then "text/plain"
    when ".yml", ".yaml" then "text/yaml"
    else "application/octet-stream"
    end
  end

  private

  def failure(message)
    { success: false, error: message }
  end
end
