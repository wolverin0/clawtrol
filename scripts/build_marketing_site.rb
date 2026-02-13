#!/usr/bin/env ruby
# frozen_string_literal: true

# Build script for /marketing static site
# Generates static HTML from workspace/marketing into public/marketing/
# Usage: ruby scripts/build_marketing_site.rb

require 'fileutils'
require 'json'
require 'time'
require 'cgi'

SOURCE_DIR = File.expand_path('~/.openclaw/workspace/marketing')
OUTPUT_DIR = File.expand_path('../public/marketing', __dir__)

# Categories mapping based on subdirectory
CATEGORIES = {
  'research' => { name: 'Research', icon: '🔬', order: 1 },
  'prompts' => { name: 'Prompts', icon: '💬', order: 2 },
  'calendar' => { name: 'Calendars', icon: '📅', order: 3 },
  'content' => { name: 'Content', icon: '📝', order: 4 },
  'generated' => { name: 'Generated Assets', icon: '🎨', order: 5 },
  'root' => { name: 'Plans', icon: '📋', order: 0 }
}

# Dark theme CSS (Futura Systems style)
CSS = <<~'CSS'
  :root {
    --bg-primary: #0a0a0f;
    --bg-secondary: #12121a;
    --bg-card: #1a1a25;
    --text-primary: #e4e4e7;
    --text-secondary: #a1a1aa;
    --accent: #22d3ee;
    --accent-hover: #06b6d4;
    --border: #27272a;
    --success: #22c55e;
    --warning: #f59e0b;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    background: var(--bg-primary);
    color: var(--text-primary);
    line-height: 1.6;
    min-height: 100vh;
  }

  .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
  }

  header {
    background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-primary) 100%);
    border-bottom: 1px solid var(--border);
    padding: 2rem 0;
    margin-bottom: 2rem;
  }

  header h1 {
    font-size: 2rem;
    font-weight: 700;
    background: linear-gradient(90deg, var(--accent), #a78bfa);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  header p {
    color: var(--text-secondary);
    margin-top: 0.5rem;
  }

  .search-box {
    margin: 1.5rem 0;
  }

  .search-box input {
    width: 100%;
    max-width: 400px;
    padding: 0.75rem 1rem;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 1rem;
  }

  .search-box input:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(34, 211, 238, 0.1);
  }

  .stats {
    display: flex;
    gap: 2rem;
    flex-wrap: wrap;
    margin-bottom: 2rem;
  }

  .stat {
    background: var(--bg-card);
    padding: 1rem 1.5rem;
    border-radius: 8px;
    border: 1px solid var(--border);
  }

  .stat-value {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--accent);
  }

  .stat-label {
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .section {
    margin-bottom: 3rem;
  }

  .section h2 {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .file-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
    gap: 1rem;
  }

  .file-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem;
    transition: all 0.2s;
  }

  .file-card:hover {
    border-color: var(--accent);
    transform: translateY(-2px);
  }

  .file-card.hidden { display: none; }

  .file-title {
    font-weight: 600;
    margin-bottom: 0.5rem;
    word-break: break-word;
  }

  .file-title a {
    color: var(--text-primary);
    text-decoration: none;
  }

  .file-title a:hover {
    color: var(--accent);
  }

  .file-meta {
    display: flex;
    gap: 1rem;
    font-size: 0.75rem;
    color: var(--text-secondary);
    margin-bottom: 0.75rem;
  }

  .file-actions {
    display: flex;
    gap: 0.5rem;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.375rem 0.75rem;
    font-size: 0.75rem;
    border-radius: 4px;
    text-decoration: none;
    transition: all 0.2s;
  }

  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
  }

  .btn-primary:hover {
    background: var(--accent-hover);
  }

  .btn-secondary {
    background: var(--bg-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border);
  }

  .btn-secondary:hover {
    border-color: var(--accent);
  }

  .thumbnail {
    width: 100%;
    max-height: 150px;
    object-fit: cover;
    border-radius: 4px;
    margin-bottom: 0.75rem;
  }

  /* Markdown content styling */
  .markdown-body {
    background: var(--bg-secondary);
    padding: 2rem;
    border-radius: 8px;
    margin-top: 1rem;
  }

  .markdown-body h1, .markdown-body h2, .markdown-body h3 {
    color: var(--accent);
    margin: 1.5rem 0 1rem;
    border-bottom: 1px solid var(--border);
    padding-bottom: 0.5rem;
  }

  .markdown-body h1:first-child { margin-top: 0; }

  .markdown-body p { margin: 1rem 0; }

  .markdown-body code {
    background: var(--bg-card);
    padding: 0.2rem 0.4rem;
    border-radius: 4px;
    font-family: 'Monaco', 'Consolas', monospace;
    font-size: 0.875em;
  }

  .markdown-body pre {
    background: var(--bg-card);
    padding: 1rem;
    border-radius: 8px;
    overflow-x: auto;
  }

  .markdown-body pre code {
    padding: 0;
    background: transparent;
  }

  .markdown-body table {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
  }

  .markdown-body th, .markdown-body td {
    border: 1px solid var(--border);
    padding: 0.5rem 1rem;
    text-align: left;
  }

  .markdown-body th {
    background: var(--bg-card);
  }

  .markdown-body a {
    color: var(--accent);
  }

  .markdown-body ul, .markdown-body ol {
    padding-left: 2rem;
    margin: 1rem 0;
  }

  .markdown-body li { margin: 0.25rem 0; }

  .markdown-body blockquote {
    border-left: 3px solid var(--accent);
    padding-left: 1rem;
    margin: 1rem 0;
    color: var(--text-secondary);
    font-style: italic;
  }

  .breadcrumb {
    margin-bottom: 1rem;
    font-size: 0.875rem;
  }

  .breadcrumb a {
    color: var(--accent);
    text-decoration: none;
  }

  .breadcrumb a:hover {
    text-decoration: underline;
  }

  footer {
    margin-top: 4rem;
    padding: 2rem 0;
    border-top: 1px solid var(--border);
    text-align: center;
    color: var(--text-secondary);
    font-size: 0.875rem;
  }

  @media (max-width: 640px) {
    .container { padding: 1rem; }
    .file-grid { grid-template-columns: 1fr; }
    .stats { gap: 1rem; }
  }
CSS

def format_size(bytes)
  return '0 B' if bytes == 0
  units = ['B', 'KB', 'MB', 'GB']
  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = units.length - 1 if exp > units.length - 1
  "#{(bytes.to_f / 1024**exp).round(1)} #{units[exp]}"
end

def extract_title(path, content = nil)
  return File.basename(path, '.*').gsub(/[-_]/, ' ').split.map(&:capitalize).join(' ') unless path.end_with?('.md')

  content ||= File.read(path) rescue ''
  # Try to get first # heading (just the first line after #)
  content.each_line do |line|
    if line.start_with?('#')
      title = line.sub(/^#+\s*/, '').strip
      return title.gsub(/[📋🔥🎯💡🚀📝💬📅🔬🎨]/, '').strip unless title.empty?
    end
  end
  File.basename(path, '.*').gsub(/[-_]/, ' ').split.map(&:capitalize).join(' ')
end

def get_category(rel_path)
  parts = rel_path.split('/')
  if parts.length > 1
    CATEGORIES[parts[0]] || CATEGORIES['root']
  else
    CATEGORIES['root']
  end
end

def generate_md_viewer_html(title, breadcrumb, raw_path)
  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{CGI.escapeHTML(title)} | Futura Marketing</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
      <style>#{CSS}</style>
    </head>
    <body>
      <header>
        <div class="container">
          <div class="breadcrumb">
            <a href="/marketing/">← Back to Marketing Docs</a>
          </div>
          <h1>#{CGI.escapeHTML(title)}</h1>
          <p>#{CGI.escapeHTML(breadcrumb)}</p>
        </div>
      </header>
      <main class="container">
        <div class="file-actions" style="margin-bottom: 1rem;">
          <a href="#{raw_path}" class="btn btn-secondary" download>⬇️ Download Raw</a>
        </div>
        <div id="content" class="markdown-body">Loading...</div>
      </main>
      <footer>
        <p>Futura Sistemas — Marketing Documentation</p>
      </footer>
      <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
      <script>
        fetch('#{raw_path}')
          .then(r => r.text())
          .then(md => {
            document.getElementById('content').innerHTML = marked.parse(md);
          })
          .catch(err => {
            document.getElementById('content').innerHTML = '<p style="color:#f87171;">Failed to load document.</p>';
          });
      </script>
    </body>
    </html>
  HTML
end

def generate_index_html(files_by_category, stats)
  sections_html = files_by_category.sort_by { |cat, _| cat[:order] }.map do |cat, files|
    cards = files.map do |f|
      thumbnail_html = ''
      if f[:is_image]
        thumbnail_html = %(<img src="#{f[:raw_path]}" alt="#{CGI.escapeHTML(f[:title])}" class="thumbnail" loading="lazy">)
      end

      <<~CARD
        <div class="file-card" data-title="#{CGI.escapeHTML(f[:title].downcase)}" data-path="#{CGI.escapeHTML(f[:path].downcase)}">
          #{thumbnail_html}
          <div class="file-title"><a href="#{f[:view_path]}">#{CGI.escapeHTML(f[:title])}</a></div>
          <div class="file-meta">
            <span>#{f[:modified]}</span>
            <span>#{f[:size]}</span>
          </div>
          <div class="file-actions">
            <a href="#{f[:view_path]}" class="btn btn-primary">📄 View</a>
            <a href="#{f[:raw_path]}" class="btn btn-secondary" download>⬇️ Raw</a>
          </div>
        </div>
      CARD
    end.join("\n")

    <<~SECTION
      <section class="section">
        <h2>#{cat[:icon]} #{cat[:name]} (#{files.length})</h2>
        <div class="file-grid">
          #{cards}
        </div>
      </section>
    SECTION
  end.join("\n")

  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Marketing Docs | Futura Sistemas</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
      <style>#{CSS}</style>
    </head>
    <body>
      <header>
        <div class="container">
          <h1>📊 Futura Marketing Hub</h1>
          <p>All marketing plans, research, prompts, calendars, and generated assets</p>
        </div>
      </header>
      <main class="container">
        <div class="search-box">
          <input type="text" id="search" placeholder="🔍 Search documents..." autocomplete="off">
        </div>
    #{'    '}
        <div class="stats">
          <div class="stat">
            <div class="stat-value">#{stats[:total]}</div>
            <div class="stat-label">Total Files</div>
          </div>
          <div class="stat">
            <div class="stat-value">#{stats[:md]}</div>
            <div class="stat-label">Documents</div>
          </div>
          <div class="stat">
            <div class="stat-value">#{stats[:images]}</div>
            <div class="stat-label">Images</div>
          </div>
        </div>

        #{sections_html}
      </main>
      <footer>
        <p>Generated #{Time.now.strftime('%Y-%m-%d %H:%M')} — Futura Sistemas</p>
      </footer>
      <script>
        document.getElementById('search').addEventListener('input', function(e) {
          const q = e.target.value.toLowerCase();
          document.querySelectorAll('.file-card').forEach(card => {
            const title = card.dataset.title || '';
            const path = card.dataset.path || '';
            card.classList.toggle('hidden', q && !title.includes(q) && !path.includes(q));
          });
        });
      </script>
    </body>
    </html>
  HTML
end

# Main build process
def build
  puts "🔨 Building marketing static site..."
  puts "   Source: #{SOURCE_DIR}"
  puts "   Output: #{OUTPUT_DIR}"

  # Clean and create output directory
  FileUtils.rm_rf(OUTPUT_DIR)
  FileUtils.mkdir_p(OUTPUT_DIR)
  FileUtils.mkdir_p(File.join(OUTPUT_DIR, 'raw'))
  FileUtils.mkdir_p(File.join(OUTPUT_DIR, 'view'))

  files_by_category = Hash.new { |h, k| h[k] = [] }
  stats = { total: 0, md: 0, images: 0 }

  # Find all files
  Dir.glob(File.join(SOURCE_DIR, '**', '*')).each do |src_path|
    next if File.directory?(src_path)
    next if src_path.include?('/.git/')

    rel_path = src_path.sub(SOURCE_DIR + '/', '')
    ext = File.extname(src_path).downcase

    # Skip non-content files
    next unless ['.md', '.png', '.jpg', '.jpeg', '.webp', '.gif', '.pdf'].include?(ext)

    stats[:total] += 1

    # Read file info
    stat = File.stat(src_path)
    is_md = ext == '.md'
    is_image = ['.png', '.jpg', '.jpeg', '.webp', '.gif'].include?(ext)

    stats[:md] += 1 if is_md
    stats[:images] += 1 if is_image

    # Copy raw file
    raw_rel = "raw/#{rel_path.gsub('/', '_')}"
    raw_path = File.join(OUTPUT_DIR, raw_rel)
    FileUtils.mkdir_p(File.dirname(raw_path))
    FileUtils.cp(src_path, raw_path)

    # Generate view page for markdown
    view_rel = nil
    if is_md
      content = File.read(src_path) rescue ''
      title = extract_title(src_path, content)

      view_rel = "view/#{rel_path.sub('.md', '.html').gsub('/', '_')}"
      view_path = File.join(OUTPUT_DIR, view_rel)

      html = generate_md_viewer_html(title, rel_path, "/marketing/#{raw_rel}")
      File.write(view_path, html)
    elsif is_image
      # For images, view = raw
      view_rel = raw_rel
    else
      view_rel = raw_rel
    end

    category = get_category(rel_path)
    files_by_category[category] << {
      path: rel_path,
      title: is_md ? extract_title(src_path) : File.basename(src_path),
      modified: stat.mtime.strftime('%Y-%m-%d'),
      size: format_size(stat.size),
      raw_path: "/marketing/#{raw_rel}",
      view_path: "/marketing/#{view_rel}",
      is_image: is_image,
      is_md: is_md
    }
  end

  # Sort files within each category
  files_by_category.each do |_, files|
    files.sort_by! { |f| f[:title].downcase }
  end

  # Generate index
  index_html = generate_index_html(files_by_category, stats)
  File.write(File.join(OUTPUT_DIR, 'index.html'), index_html)

  puts "\n✅ Build complete!"
  puts "   📄 #{stats[:md]} documents"
  puts "   🖼️  #{stats[:images]} images"
  puts "   📁 #{stats[:total]} total files"
  puts "   🌐 Access at: /marketing/"
end

# Run
build
