# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

class SoulEditorController < ApplicationController
  before_action :require_authentication

  WORKSPACE = File.expand_path("~/.openclaw/workspace")
  HISTORY_DIR = Rails.root.join("storage", "soul-history")
  ALLOWED_FILES = %w[SOUL.md IDENTITY.md USER.md AGENTS.md].freeze
  MAX_HISTORY = 20

  # GET /soul-editor
  def show
    file_name = selected_file
    data = file_payload(file_name)

    if request.xhr? || request.format.json?
      render json: data
    else
      @active_file = file_name
      @content = data[:content]
      @last_modified = data[:last_modified]
      @allowed_files = ALLOWED_FILES
    end
  rescue StandardError => e
    handle_error(e)
  end

  # PATCH /soul-editor
  def update
    file_name = selected_file
    file_path = workspace_file_path(file_name)
    new_content = params[:content].to_s

    old_content = File.exist?(file_path) ? File.read(file_path) : ""
    push_history(file_name, old_content)

    File.write(file_path, new_content)
    last_modified = File.mtime(file_path).iso8601

    render json: { success: true, file: file_name, last_modified: last_modified }
  rescue StandardError => e
    handle_error(e)
  end

  # GET /soul-editor/history
  def history
    file_name = selected_file
    render json: { success: true, file: file_name, history: read_history(file_name) }
  rescue StandardError => e
    handle_error(e)
  end

  # POST /soul-editor/revert
  def revert
    file_name = selected_file
    timestamp = params[:timestamp].to_s
    versions = read_history(file_name)
    version = versions.find { |entry| entry["timestamp"] == timestamp }

    return render json: { success: false, error: "Version not found" }, status: :not_found if version.blank?

    file_path = workspace_file_path(file_name)
    current_content = File.exist?(file_path) ? File.read(file_path) : ""
    push_history(file_name, current_content)

    File.write(file_path, version["content"].to_s)
    last_modified = File.mtime(file_path).iso8601

    render json: {
      success: true,
      file: file_name,
      content: version["content"].to_s,
      last_modified: last_modified
    }
  rescue StandardError => e
    handle_error(e)
  end

  # GET /soul-editor/templates
  def templates
    file_name = selected_file

    if file_name != "SOUL.md"
      return render json: { success: true, templates: [] }
    end

    render json: { success: true, templates: soul_templates }
  rescue StandardError => e
    handle_error(e)
  end

  private

  def selected_file
    requested = params[:file].presence || "SOUL.md"
    return requested if ALLOWED_FILES.include?(requested)

    raise ArgumentError, "Invalid file"
  end

  def workspace_file_path(file_name)
    path = File.expand_path(File.join(WORKSPACE, file_name))
    raise ArgumentError, "Invalid path" unless path.start_with?("#{WORKSPACE}/")

    path
  end

  def file_payload(file_name)
    path = workspace_file_path(file_name)
    content = File.exist?(path) ? File.read(path) : ""
    mtime = File.exist?(path) ? File.mtime(path).iso8601 : nil

    {
      success: true,
      file: file_name,
      content: content,
      last_modified: mtime
    }
  end

  def history_file_path(file_name)
    HISTORY_DIR.join("#{file_name}-history.json")
  end

  def read_history(file_name)
    path = history_file_path(file_name)
    return [] unless File.exist?(path)

    parsed = JSON.parse(File.read(path))
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end

  def push_history(file_name, content)
    FileUtils.mkdir_p(HISTORY_DIR)
    versions = read_history(file_name)
    versions << { timestamp: Time.current.iso8601, content: content.to_s }
    versions = versions.last(MAX_HISTORY)
    File.write(history_file_path(file_name), JSON.pretty_generate(versions))
  end

  def soul_templates
    [
      {
        id: "minimal-assistant",
        name: "Minimal Assistant",
        description: "Be helpful. Be concise. No fluff.",
        content: "# SOUL\n\nYou are a minimal assistant.\n\n## Core Behavior\n- Be helpful.\n- Be concise.\n- No fluff.\n"
      },
      {
        id: "friendly-companion",
        name: "Friendly Companion",
        description: "Warm, conversational, emoji-forward tone.",
        content: "# SOUL\n\nYou are a friendly companion.\n\n## Voice\n- Warm and conversational\n- Encouraging and empathetic\n- Use emoji naturally\n"
      },
      {
        id: "technical-expert",
        name: "Technical Expert",
        description: "Precise, code-focused, opinionated guidance.",
        content: "# SOUL\n\nYou are a technical expert.\n\n## Style\n- Precise and direct\n- Code-first explanations\n- Strong, reasoned opinions\n"
      },
      {
        id: "creative-partner",
        name: "Creative Partner",
        description: "Brainstormy and imaginative collaborator.",
        content: "# SOUL\n\nYou are a creative partner.\n\n## Approach\n- Explore possibilities\n- Offer imaginative alternatives\n- Build on the user's ideas\n"
      },
      {
        id: "stern-operator",
        name: "Stern Operator",
        description: "Military-efficient with dry humor.",
        content: "# SOUL\n\nYou are a stern operator.\n\n## Behavior\n- Crisp and efficient\n- Prioritize execution and verification\n- Dry humor when useful\n"
      },
      {
        id: "sarcastic-sidekick",
        name: "Sarcastic Sidekick",
        description: "Witty, helpful, with commentary.",
        content: "# SOUL\n\nYou are a sarcastic sidekick.\n\n## Tone\n- Witty and sharp\n- Still practical and helpful\n- Commentary should never block clarity\n"
      }
    ]
  end

  def handle_error(error)
    respond_to do |format|
      format.html { redirect_to soul_editor_path, alert: "Error: #{error.message}" }
      format.json { render json: { success: false, error: error.message }, status: :unprocessable_entity }
      format.any { render json: { success: false, error: error.message }, status: :unprocessable_entity }
    end
  end
end
