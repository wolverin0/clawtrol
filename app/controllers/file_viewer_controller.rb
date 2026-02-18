# frozen_string_literal: true

class FileViewerController < ApplicationController
  rate_limit to: 60, within: 1.minute, with: -> { render plain: "Rate limit exceeded. Try again later.", status: :too_many_requests }
  include MarkdownSanitizationHelper

  WORKSPACE = Pathname.new(File.expand_path("~/.openclaw/workspace")).freeze
  WORKSPACE_PREFIX = (WORKSPACE.to_s + "/").freeze
  REPORTS_DIR = Pathname.new(File.expand_path("~/nightshift-reports")).freeze
  CLAWDECK_DIR = Pathname.new(File.expand_path("~/clawdeck")).freeze
  ALLOWED_DIRS = [WORKSPACE, REPORTS_DIR, CLAWDECK_DIR].freeze

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

    # Raw format: return plain text content (for editor fetch)
    if params[:format] == "raw"
      render plain: content, content_type: "text/plain"
      return
    end
    ext = resolved.extname.downcase

    # For .html files: support preview mode via iframe, or show source with toggle
    if ext == ".html" || ext == ".htm"
      mode = params[:mode].to_s
      if mode == "preview"
        # Serve the raw HTML in a sandboxed way
        render inline: html_preview_template(relative, content), content_type: "text/html"
        return
      elsif mode == "raw"
        # Serve raw HTML for iframe src — sandboxed with strict CSP
        response.headers["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; img-src data: https:; sandbox"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        render inline: content, content_type: "text/html"
        return
      end
    end

    body = if ext == ".md"
      # Use safe_markdown for XSS-safe rendering
      safe_markdown(content)
    elsif ext == ".html" || ext == ".htm"
      html_source_with_preview(relative, content)
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

  def update
    relative = params[:file] || request.request_parameters["file"]
    content = request.request_parameters["content"]

    if relative.blank?
      render json: { error: "No file specified" }, status: :bad_request
      return
    end

    if content.nil?
      render json: { error: "No content provided" }, status: :bad_request
      return
    end

    # For new files, we need to handle the case where the file doesn't exist yet
    resolved = resolve_safe_path(relative)

    # If file doesn't exist, try to create it in workspace
    unless resolved
      # Only allow creation in workspace
      candidate = (WORKSPACE / relative.to_s.sub(%r{\A/+}, "")).expand_path
      if candidate.to_s.start_with?(WORKSPACE_PREFIX) && !relative.match?(HIDDEN_PATTERN)
        # Create parent directories if needed
        candidate.dirname.mkpath
        resolved = candidate
      else
        render json: { error: "Access denied" }, status: :forbidden
        return
      end
    end

    begin
      File.write(resolved.to_s, content)
      render json: { ok: true }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
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

  def html_source_with_preview(relative, content)
    escaped = ERB::Util.html_escape(content)
    preview_url = ERB::Util.html_escape("/view?file=#{relative}&mode=raw")
    <<~HTML
      <div style="margin-bottom:16px;">
        <button onclick="toggleHtmlView()" id="toggle-btn"
                style="padding:6px 14px;font-size:12px;background:#6366f1;color:#fff;border:none;border-radius:6px;cursor:pointer;margin-right:8px;">
          🔍 Preview
        </button>
        <span id="view-label" style="font-size:12px;color:#888;">Showing: Source Code</span>
      </div>
      <div id="source-view">
        <pre>#{escaped}</pre>
      </div>
      <div id="preview-view" style="display:none;">
        <iframe src="#{preview_url}" sandbox="allow-same-origin"
                style="width:100%;height:80vh;border:1px solid #333;border-radius:8px;background:#fff;"></iframe>
      </div>
      <script>
        function toggleHtmlView() {
          var src = document.getElementById('source-view');
          var prev = document.getElementById('preview-view');
          var btn = document.getElementById('toggle-btn');
          var label = document.getElementById('view-label');
          if (src.style.display !== 'none') {
            src.style.display = 'none';
            prev.style.display = 'block';
            btn.textContent = '📝 Source';
            label.textContent = 'Showing: Preview';
          } else {
            src.style.display = 'block';
            prev.style.display = 'none';
            btn.textContent = '🔍 Preview';
            label.textContent = 'Showing: Source Code';
          }
        }
      </script>
    HTML
  end

  def html_preview_template(relative, content)
    # Full preview page with back link
    escaped_title = ERB::Util.html_escape(relative)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Preview: #{escaped_title}</title>
        <style>
          body { margin: 0; padding: 16px; font-family: system-ui; background: #0f0f11; color: #e5e5e5; }
          .toolbar { padding: 8px 0; margin-bottom: 12px; border-bottom: 1px solid #333; display: flex; align-items: center; gap: 12px; }
          .toolbar a { color: #818cf8; text-decoration: none; font-size: 13px; }
          .toolbar a:hover { text-decoration: underline; }
          iframe { width: 100%; height: calc(100vh - 80px); border: 1px solid #333; border-radius: 8px; background: #fff; }
        </style>
      </head>
      <body>
        <div class="toolbar">
          <a href="/view?file=#{ERB::Util.html_escape(relative)}">← Back to source</a>
          <span style="font-size:12px;color:#888;">Preview: #{escaped_title}</span>
        </div>
        <iframe src="/view?file=#{ERB::Util.html_escape(relative)}&mode=raw" sandbox="allow-same-origin"></iframe>
      </body>
      </html>
    HTML
  end

  def page_template(title, body)
    escaped_title = ERB::Util.html_escape(title)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="#{form_authenticity_token}">
        <title>#{escaped_title} — ClawTrol Viewer</title>
        <style>
          *{box-sizing:border-box;margin:0;padding:0}
          body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;line-height:1.6;padding:2rem}
          .container{max-width:900px;margin:0 auto}
          .header{border-bottom:1px solid #30363d;padding-bottom:1rem;margin-bottom:2rem;display:flex;align-items:center;gap:0.5rem;flex-wrap:wrap}
          .header h1{font-size:1.1rem;color:#58a6ff;font-weight:500;flex:1}
          .header .icon{font-size:1.3rem}
          .header-actions{display:flex;gap:0.5rem;align-items:center}
          .edit-btn,.save-btn,.cancel-btn{padding:6px 14px;font-size:12px;border:none;border-radius:6px;cursor:pointer;font-weight:500}
          .edit-btn{background:#6366f1;color:#fff}
          .edit-btn:hover{background:#5558e3}
          .edit-btn.dirty{background:#f59e0b}
          .save-btn{background:#22c55e;color:#fff}
          .save-btn:hover{background:#16a34a}
          .cancel-btn{background:#4b5563;color:#fff}
          .cancel-btn:hover{background:#6b7280}
          .dirty-indicator{color:#f59e0b;font-size:14px;margin-left:4px}
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
          .editor-container{display:none}
          .editor-textarea{width:100%;min-height:70vh;background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:8px;padding:1rem;font-family:'SF Mono',Monaco,'Cascadia Code',Consolas,monospace;font-size:14px;line-height:1.5;resize:vertical}
          .editor-textarea:focus{outline:none;border-color:#6366f1}
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <span class="icon">📄</span>
            <h1>#{escaped_title}<span class="dirty-indicator" id="dirty-dot" style="display:none">●</span></h1>
            <div class="header-actions">
              <button class="edit-btn" id="edit-btn" onclick="enterEditMode()">✏️ Edit</button>
              <button class="save-btn" id="save-btn" onclick="saveFile()" style="display:none">💾 Save</button>
              <button class="cancel-btn" id="cancel-btn" onclick="cancelEdit()" style="display:none">❌ Cancel</button>
            </div>
          </div>
          <div class="content" id="view-content">#{body}</div>
          <div class="editor-container" id="editor-container">
            <textarea class="editor-textarea" id="editor-textarea" spellcheck="false"></textarea>
          </div>
        </div>
        <script>
          var isDirty = false;
          var originalContent = '';
          var currentFile = #{title.to_json};

          function enterEditMode() {
            var editBtn = document.getElementById('edit-btn');
            var saveBtn = document.getElementById('save-btn');
            var cancelBtn = document.getElementById('cancel-btn');
            var viewContent = document.getElementById('view-content');
            var editorContainer = document.getElementById('editor-container');
            var textarea = document.getElementById('editor-textarea');

            editBtn.textContent = '⏳ Loading...';
            editBtn.disabled = true;

            fetch(window.location.pathname + '?file=' + encodeURIComponent(currentFile) + '&format=raw')
              .then(function(r) { return r.text(); })
              .then(function(content) {
                originalContent = content;
                textarea.value = content;
                isDirty = false;
                updateDirtyIndicator();

                viewContent.style.display = 'none';
                editorContainer.style.display = 'block';
                editBtn.style.display = 'none';
                saveBtn.style.display = 'inline-block';
                cancelBtn.style.display = 'inline-block';
                textarea.focus();
              })
              .catch(function(e) {
                alert('Failed to load file: ' + e.message);
                editBtn.textContent = '✏️ Edit';
                editBtn.disabled = false;
              });
          }

          function saveFile() {
            var textarea = document.getElementById('editor-textarea');
            var saveBtn = document.getElementById('save-btn');
            saveBtn.textContent = '⏳ Saving...';
            saveBtn.disabled = true;

            fetch(window.location.pathname + '?file=' + encodeURIComponent(currentFile), {
              method: 'PUT',
              headers: {
                  'Content-Type': 'application/json',
                  'X-CSRF-Token': (document.querySelector('meta[name=\"csrf-token\"]') || {}).content || ''
                },
              body: JSON.stringify({ file: currentFile, content: textarea.value })
            })
            .then(function(r) { return r.json(); })
            .then(function(data) {
              if (data.ok) {
                window.location.reload();
              } else {
                alert('Save failed: ' + (data.error || 'Unknown error'));
                saveBtn.textContent = '💾 Save';
                saveBtn.disabled = false;
              }
            })
            .catch(function(e) {
              alert('Save failed: ' + e.message);
              saveBtn.textContent = '💾 Save';
              saveBtn.disabled = false;
            });
          }

          function cancelEdit() {
            if (isDirty && !confirm('Discard unsaved changes?')) return;

            var editBtn = document.getElementById('edit-btn');
            var saveBtn = document.getElementById('save-btn');
            var cancelBtn = document.getElementById('cancel-btn');
            var viewContent = document.getElementById('view-content');
            var editorContainer = document.getElementById('editor-container');

            viewContent.style.display = 'block';
            editorContainer.style.display = 'none';
            editBtn.style.display = 'inline-block';
            editBtn.textContent = '✏️ Edit';
            editBtn.disabled = false;
            saveBtn.style.display = 'none';
            cancelBtn.style.display = 'none';
            isDirty = false;
            updateDirtyIndicator();
          }

          function updateDirtyIndicator() {
            var dot = document.getElementById('dirty-dot');
            dot.style.display = isDirty ? 'inline' : 'none';
          }

          document.getElementById('editor-textarea').addEventListener('input', function() {
            isDirty = this.value !== originalContent;
            updateDirtyIndicator();
          });

          document.addEventListener('keydown', function(e) {
            if ((e.ctrlKey || e.metaKey) && e.key === 's') {
              var editorContainer = document.getElementById('editor-container');
              if (editorContainer.style.display !== 'none') {
                e.preventDefault();
                saveFile();
              }
            }
          });

          window.addEventListener('beforeunload', function(e) {
            if (isDirty) {
              e.preventDefault();
              e.returnValue = '';
            }
          });
        </script>
      </body>
      </html>
    HTML
  end

  def error_page(message)
    page_template("Error", "<h2>#{ERB::Util.html_escape(message)}</h2>")
  end
end
