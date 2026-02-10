# frozen_string_literal: true

class MarketingController < ApplicationController
  MARKETING_ROOT = Rails.root.join("..", "..", ".openclaw", "workspace", "marketing").to_s.freeze
  VIEWABLE_EXTENSIONS = %w[.md .json .html .txt .yml .yaml].freeze
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg].freeze

  skip_before_action :require_authentication, only: [:index, :show]

  def index
    @search_query = params[:q].to_s.strip
    @tree = build_tree(MARKETING_ROOT, @search_query)
  end

  def show
    relative_path = sanitize_path(params[:path])
    @file_path = File.join(MARKETING_ROOT, relative_path)

    unless File.exist?(@file_path) && File.file?(@file_path)
      render plain: "File not found", status: :not_found
      return
    end

    @relative_path = relative_path
    @extension = File.extname(@file_path).downcase
    @filename = File.basename(@file_path)

    if viewable?(@extension)
      @content = File.read(@file_path, encoding: "UTF-8")
      @rendered_content = render_content(@content, @extension)
    elsif image?(@extension)
      @is_image = true
      @image_data = Base64.strict_encode64(File.binread(@file_path))
      @mime_type = mime_type_for(@extension)
    else
      @is_binary = true
    end
  end

  private

  def sanitize_path(path)
    # Prevent directory traversal attacks
    return "" if path.blank?

    # Normalize and reject any path containing ..
    cleaned = path.to_s.gsub("\\", "/")
    return "" if cleaned.include?("..")

    # Remove leading slashes
    cleaned.sub(%r{^/+}, "")
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
    renderer = Redcarpet::Render::HTML.new(
      filter_html: false,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      highlight: true,
      footnotes: true
    )
    markdown.render(content).html_safe
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
      ".svg" => "image/svg+xml"
    }[ext] || "application/octet-stream"
  end
end
