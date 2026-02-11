class FileViewerController < ApplicationController
  include MarkdownSanitizationHelper

  WORKSPACE = Pathname.new(File.expand_path("~/.openclaw/workspace")).freeze

  def show
    relative = params[:file].to_s
    if relative.blank?
      render inline: error_page("No file specified"), status: :bad_request, content_type: "text/html"
      return
    end

    # Sanitize: expand and ensure it's under workspace
    full = (WORKSPACE / relative).expand_path
    unless full.to_s.start_with?(WORKSPACE.to_s + "/")
      render inline: error_page("Access denied"), status: :forbidden, content_type: "text/html"
      return
    end

    unless full.file?
      render inline: error_page("File not found: #{relative}"), status: :not_found, content_type: "text/html"
      return
    end

    content = full.read(encoding: "utf-8")
    ext = full.extname.downcase

    body = if ext == ".md"
      # Use safe_markdown for XSS-safe rendering
      safe_markdown(content)
    else
      "<pre>#{ERB::Util.html_escape(content)}</pre>"
    end

    render inline: page_template(relative, body), content_type: "text/html"
  end

  private

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
