# frozen_string_literal: true

# Shared helper for secure markdown rendering with XSS protection.
# ALWAYS use this instead of raw .html_safe on Redcarpet output!
module MarkdownSanitizationHelper
  extend ActiveSupport::Concern

  # Tags allowed in sanitized markdown output
  SAFE_TAGS = %w[
    p h1 h2 h3 h4 h5 h6
    ul ol li
    table thead tbody tfoot tr th td
    code pre
    blockquote
    a strong em b i u s del strike
    img br hr
    sup sub mark
    span div
    dl dt dd
  ].freeze

  # Attributes allowed on specific tags
  SAFE_ATTRIBUTES = {
    "a" => %w[href title target rel],
    "img" => %w[src alt title width height],
    "code" => %w[class],
    "pre" => %w[class],
    "span" => %w[class],
    "div" => %w[class],
    "td" => %w[colspan rowspan],
    "th" => %w[colspan rowspan scope],
    "table" => %w[class]
  }.freeze

  # Render markdown to sanitized HTML (safe from XSS)
  # @param content [String] raw markdown content
  # @param options [Hash] options for Redcarpet
  # @return [ActiveSupport::SafeBuffer] sanitized HTML safe for rendering
  def safe_markdown(content, options = {})
    return "".html_safe if content.blank?

    html = render_raw_markdown(content, options)
    sanitize_html(html).html_safe
  end

  # Sanitize arbitrary HTML (use for any user-provided HTML)
  # @param html [String] raw HTML
  # @return [String] sanitized HTML (NOT marked html_safe - caller decides)
  def sanitize_html(html)
    return "" if html.blank?

    sanitizer = Rails::HTML5::SafeListSanitizer.new
    sanitizer.sanitize(
      html,
      tags: SAFE_TAGS,
      attributes: SAFE_ATTRIBUTES.values.flatten.uniq
    )
  end

  private

  def render_raw_markdown(content, options = {})
    renderer_options = {
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    }.merge(options.fetch(:renderer, {}))

    renderer = Redcarpet::Render::HTML.new(**renderer_options)

    markdown_options = {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      highlight: true,
      no_intra_emphasis: true
    }.merge(options.fetch(:markdown, {}))

    markdown = Redcarpet::Markdown.new(renderer, **markdown_options)
    markdown.render(content)
  end
end
