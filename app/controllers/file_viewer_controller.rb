# frozen_string_literal: true

class FileViewerController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.minute, with: -> { render plain: "Rate limit exceeded. Try again later.", status: :too_many_requests }
  include MarkdownSanitizationHelper

  WORKSPACE = Pathname.new(File.expand_path("~/.openclaw/workspace")).freeze
  WORKSPACE_PREFIX = (WORKSPACE.to_s + "/").freeze
  REPORTS_DIR = Pathname.new(File.expand_path("~/nightshift-reports")).freeze
  ALLOWED_DIRS = [WORKSPACE, REPORTS_DIR].freeze

  # Dotfiles/dotdirs that should never be served or listed
  HIDDEN_PATTERN = /(?:^|\/)\.[^\/]/

  # Maximum file size to serve (2 MB) — prevents memory exhaustion
  MAX_FILE_SIZE = 2 * 1024 * 1024

  def show
    relative = params[:file].to_s
    if relative.blank?
      render inline: error_page("No file specified"), status: :bad_request, content_type: "text/html"
      return
    end

    resolved = resolve_safe_path(relative)
    unless resolved
      render inline: error_page("Access denied"), status: :forbidden, content_type: "text/html"
      return
    end

    unless resolved.file?
      render inline: error_page("File not found: #{relative}"), status: :not_found, content_type: "text/html"
      return
    end

    if resolved.size > MAX_FILE_SIZE
      render inline: error_page("File too large (max #{MAX_FILE_SIZE / 1024}KB)"), status: :unprocessable_entity, content_type: "text/html"
      return
    end

    content = resolved.read(encoding: "utf-8")
    ext = resolved.extname.downcase

    body = if ext == ".md"
      # Use safe_markdown for XSS-safe rendering
      safe_markdown(content)
    else
      "<pre>#{ERB::Util.html_escape(content)}</pre>"
    end

    render inline: page_template(relative, body), content_type: "text/html"
  end

  def browse
    relative = params[:path].to_s

    if relative.blank?
      dir_path = WORKSPACE
    else
      dir_path = resolve_safe_path(relative)
      unless dir_path
        render plain: "Access denied", status: :forbidden
        return
      end
    end

    unless dir_path.directory?
      render plain: "Not a directory", status: :not_found
      return
    end

    # Filter out dotfiles/dotdirs from listing (e.g. .git, .env)
    @entries = dir_path.children
      .reject { |c| c.basename.to_s.start_with?(".") }
      .sort_by { |c| [c.directory? ? 0 : 1, c.basename.to_s.downcase] }
    @current_path = relative
    @parent_path = relative.include?("/") ? File.dirname(relative) : nil
  end

  private

  def resolve_allowed_path(relative)
    cleaned = relative.to_s.sub(%r{\A/+}, "")

    matched_base = ALLOWED_DIRS.find do |base|
      base_name = base.basename.to_s
      cleaned == base_name || cleaned.start_with?("#{base_name}/")
    end

    if matched_base
      base_name = matched_base.basename.to_s
      suffix = cleaned == base_name ? "" : cleaned.delete_prefix("#{base_name}/")
      candidate = (matched_base / suffix).expand_path
      return candidate if path_allowed?(candidate)
    end

    workspace_candidate = (WORKSPACE / cleaned).expand_path
    return workspace_candidate if path_allowed?(workspace_candidate)

    nil
  end

  def path_allowed?(path)
    ALLOWED_DIRS.any? do |base|
      path == base || path.to_s.start_with?(base.to_s + "/")
    end
  end

  # Resolve a relative path to an absolute path safely within ALLOWED_DIRS.
  # Returns nil if the path is rejected for any security reason.
  # Checks: null bytes, dotfiles/dotdirs, empty components, directory traversal,
  # and symlink escape (using File.realpath).
  def resolve_safe_path(relative)
    # Reject null bytes (can truncate paths at C level)
    return nil if relative.include?("\x00")

    # Reject dotfiles/dotdirs (.env, .git, .gitignore, etc.)
    return nil if relative.match?(HIDDEN_PATTERN)

    # Reject empty path components (double slashes)
    return nil if relative.include?("//") || relative.start_with?("/")

    # Use the existing multi-dir resolver for logical path resolution
    candidate = resolve_allowed_path(relative)
    return nil unless candidate

    # File/dir must exist for realpath to work
    return nil unless candidate.exist?

    # Resolve symlinks and verify the real path is still inside an allowed directory
    real = Pathname.new(File.realpath(candidate.to_s))
    return nil unless path_allowed?(real)

    real
  end

  def page_template(title, body)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{ERB::Util.html_escape(title)} — ClawTrol Viewer</title>
        <style>
          *{box-sizing:border-box;margin:0;padding:0}
          body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;line-height:1.6;padding:2rem}
          .container{max-width:900px;margin:0 auto}
          .header{border-bottom:1px solid #30363d;padding-bottom:1rem;margin-bottom:2rem;display:flex;align-items:center;gap:0.5rem}
          .header h1{font-size:1.1rem;color:#58a6ff;font-weight:500}
          .header .icon{font-size:1.3rem}
          .content h1,.content h2,.content h3,.content h4{color:#e6edf3;margin:1.5em 0 0.5em}
          .content h1{font-size:1.8rem;border-bottom:1px solid #30363d;padding-bottom:0.3em}
          .content h2{font-size:1.4rem;border-bottom:1px solid #21262d;padding-bottom:0.3em}
          .content h3{font-size:1.15rem}
          .content p{margin:0.5em 0}
          .content a{color:#58a6ff;text-decoration:none}
          .content a:hover{text-decoration:underline}
          .content code{background:#161b22;padding:0.2em 0.4em;border-radius:4px;font-size:0.9em;color:#f0883e}
          .content pre{background:#161b22;padding:1rem;border-radius:8px;overflow-x:auto;margin:1em 0;border:1px solid #30363d}
          .content pre code{background:none;padding:0;color:#c9d1d9}
          .content table{border-collapse:collapse;width:100%;margin:1em 0}
          .content th,.content td{border:1px solid #30363d;padding:0.5em 0.8em;text-align:left}
          .content th{background:#161b22;color:#e6edf3}
          .content tr:nth-child(even){background:#161b2205}
          .content ul,.content ol{margin:0.5em 0 0.5em 1.5em}
          .content li{margin:0.2em 0}
          .content blockquote{border-left:3px solid #30363d;padding-left:1em;color:#8b949e;margin:1em 0}
          .content hr{border:none;border-top:1px solid #30363d;margin:2em 0}
          .content img{max-width:100%}
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header"><span class="icon">📄</span><h1>#{ERB::Util.html_escape(title)}</h1></div>
          <div class="content">#{body}</div>
        </div>
      </body>
      </html>
    HTML
  end

  def error_page(message)
    page_template("Error", "<h2>#{ERB::Util.html_escape(message)}</h2>")
  end
end
