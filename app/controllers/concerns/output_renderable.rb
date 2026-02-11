# frozen_string_literal: true

# Shared helpers for rendering task outputs (HTML, images, markdown)
# Used by PreviewsController and ShowcasesController
module OutputRenderable
  extend ActiveSupport::Concern
  include MarkdownSanitizationHelper

  included do
    helper_method :render_markdown if respond_to?(:helper_method)
  end

  private

  # Security: Validate and resolve path to prevent directory traversal
  # SECURITY FIX #495: Only allow relative paths within explicitly allowed directories
  # Rejects: absolute paths, ~/paths, dotfiles/dotdirs, path traversal, null bytes
  def resolve_safe_path(path, allowed_dirs: nil)
    path = path.to_s.strip
    return nil if path.blank?

    # SECURITY: Reject paths with null bytes (could bypass checks in some contexts)
    return nil if path.include?("\x00")

    # SECURITY: Reject absolute paths and ~/ paths entirely
    return nil if path.start_with?('/')
    return nil if path.start_with?('~')

    # SECURITY: Block dotfiles/dotdirs - any path component starting with '.'
    # This covers .openclaw, .ssh, .gnupg, .env, .config, etc.
    path_components = path.split('/')
    return nil if path_components.any? { |component| component.start_with?('.') && component != '.' }

    # Define allowed base directories (project and storage only)
    project_root = File.expand_path("~/clawdeck")
    storage_root = File.expand_path("~/clawdeck/storage")

    # Allow caller to override allowed_dirs (for board-specific project paths)
    allowed_dirs ||= [project_root, storage_root]
    allowed_dirs = allowed_dirs.map { |d| File.expand_path(d) }

    # Try to resolve against each allowed directory
    full_path = nil
    allowed_dirs.each do |base_dir|
      candidate = File.expand_path(File.join(base_dir, path))

      # SECURITY: Ensure resolved path is still within the allowed directory
      # This prevents ../ traversal attacks
      if candidate.start_with?(base_dir + '/') || candidate == base_dir
        # Check if file exists in this location
        if File.exist?(candidate)
          full_path = candidate
          break
        elsif full_path.nil?
          # Keep first candidate as fallback for error messages
          full_path = candidate
        end
      end
    end

    return nil unless full_path

    # Final safety check: ensure path is within one of the allowed directories
    unless allowed_dirs.any? { |dir| full_path.start_with?(dir + '/') || full_path == dir }
      return nil
    end

    full_path
  end

  # Read output file with size limit
  def read_output_file(path)
    full_path = resolve_safe_path(path)
    return nil unless full_path
    return nil unless File.exist?(full_path)
    return nil if File.size(full_path) > 10.megabytes

    File.read(full_path)
  rescue StandardError => e
    Rails.logger.warn("[OutputRenderable] Failed to read file #{path}: #{e.message}")
    nil
  end

  # Render markdown content to sanitized HTML (XSS-safe)
  # Uses MarkdownSanitizationHelper for secure rendering
  def render_markdown(content)
    safe_markdown(content)
  end

  # Extract ## Agent Output section from task description
  def extract_agent_output(description)
    match = description.to_s.match(/## Agent Output\s*(.*)/m)
    return nil unless match

    output = match[1].to_s.strip

    # Stop at the next ## heading if present
    if output.include?("\n## ")
      output = output.split(/\n## /).first
    end

    # Skip if it looks like raw JSONL transcript data
    return nil if output.to_s.match?(/\A\s*\{.*"type"\s*:\s*"message"/)
    return nil if output.to_s.scan(/\{"type":"message"/).size > 2

    output.presence
  end

  # Find and read first HTML file in task's output_files
  def read_first_html_file(task)
    return nil unless task.output_files.present?

    html_file = task.output_files.find { |f| f.to_s.end_with?('.html', '.htm') }
    return nil unless html_file

    read_output_file(html_file)
  end

  # Find ALL HTML files in task's output_files (for multi-variant showcase)
  def find_all_html_files(task)
    return [] unless task.output_files.present?

    task.output_files.select { |f| f.to_s.end_with?('.html', '.htm') }
  end

  # Read a specific HTML file by path (for tabbed gallery)
  def read_html_file_by_path(task, path)
    return nil unless task.output_files.present?
    return nil unless task.output_files.include?(path)

    read_output_file(path)
  end

  # Generate file URL for viewing
  def file_url(task, path)
    view_file_board_task_path(task.board, task, path: path)
  end

  # Extract preview content from task (HTML, images, markdown, or description)
  def extract_preview_content(task)
    # Priority 1: HTML files in output_files (support multiple variants)
    if task.output_files.present?
      html_files = find_all_html_files(task)
      if html_files.any?
        # Return all HTML files for tabbed/gallery view
        files_with_content = html_files.map do |path|
          filename = File.basename(path, File.extname(path))
          # Create user-friendly label (e.g., "variant-1" -> "Variant 1")
          label = filename.gsub(/[-_]/, ' ').titleize
          { path: path, label: label }
        end
        # Use first file as default content for backwards compatibility
        first_content = read_output_file(html_files.first)
        return { 
          type: :html, 
          content: first_content, 
          path: html_files.first,
          all_files: files_with_content,
          multiple: html_files.size > 1
        } if first_content
      end

      # Check for images
      image_files = task.output_files.select { |f| f.to_s.match?(/\.(png|jpe?g|gif|webp|svg)$/i) }
      if image_files.any?
        return { type: :images, files: image_files.map { |f| { path: f, url: file_url(task, f) } } }
      end

      # Check for markdown files
      md_file = task.output_files.find { |f| f.to_s.end_with?('.md', '.markdown') }
      if md_file
        content = read_output_file(md_file)
        return { type: :markdown, content: content, path: md_file } if content
      end
    end

    # Priority 2: Extract ## Agent Output section from description
    if task.description.to_s.include?("## Agent Output")
      agent_output = extract_agent_output(task.description)
      return { type: :markdown, content: agent_output, source: :description } if agent_output.present?
    end

    # Priority 3: Full description as markdown
    if task.description.present?
      return { type: :markdown, content: task.description, source: :full_description }
    end

    { type: :none }
  end
end
