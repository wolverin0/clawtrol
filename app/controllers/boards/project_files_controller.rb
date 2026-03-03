# frozen_string_literal: true

module Boards
  class ProjectFilesController < ApplicationController
    before_action :require_authentication
    before_action :set_board
    before_action :set_project_file, only: [:show, :destroy]

    ALLOWED_EXTENSIONS = %w[.md .py .rb .sh .txt .yml .yaml .json .toml .cfg .env].freeze
    EDITABLE_EXTENSIONS = %w[.md .txt].freeze
    MAX_FILE_SIZE = 500.kilobytes

    def index
      @pinned_files = @board.project_files.pinned.by_position
      @tree = build_tree
      @active_file_path = params[:path].presence || @pinned_files.first&.file_path
      @active_file = @active_file_path.present? ? read_payload(@active_file_path) : nil

      if turbo_frame_request? && request.headers["Turbo-Frame"] == "board_files_modal"
        render :index
      end
    end

    def show
      render json: read_payload(@project_file.file_path)
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    def create
      path = params[:file_path].to_s
      return render json: { success: false, error: "Seleccioná un archivo para fijar." }, status: :unprocessable_entity if path.blank?
      return render json: { success: false, error: "Ruta inválida. Elegí un archivo dentro del proyecto del board." }, status: :unprocessable_entity unless valid_readable_path?(path)

      project_file = @board.project_files.find_or_initialize_by(file_path: resolve_path(path))
      project_file.label = params[:label] if params.key?(:label)
      project_file.pinned = true
      project_file.position = next_position if project_file.new_record?
      project_file.save!

      respond_to do |format|
        format.html { redirect_to board_project_files_path(@board, path: project_file.file_path), notice: "File pinned" }
        format.json { render json: { success: true, project_file: serialize_project_file(project_file) } }
      end
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    def destroy
      @project_file.destroy!

      respond_to do |format|
        format.html { redirect_to board_project_files_path(@board), notice: "File unpinned" }
        format.json { render json: { success: true } }
      end
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    def tree
      render json: { success: true, tree: build_tree }
    end

    def read
      path = params[:path].to_s
      return render json: { success: false, error: "Seleccioná un archivo." }, status: :unprocessable_entity if path.blank?
      return render json: { success: false, error: "Ruta inválida. Solo se permiten archivos dentro del proyecto del board." }, status: :unprocessable_entity unless valid_readable_path?(path)

      render json: read_payload(path)
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    def save
      path = params[:file_path].to_s
      return render json: { success: false, error: "Seleccioná un archivo para guardar." }, status: :unprocessable_entity if path.blank?

      abs = resolve_path(path)
      return render json: { success: false, error: "Ruta inválida. Solo se permiten archivos dentro del proyecto del board." }, status: :forbidden unless safe_path?(abs)
      return render json: { success: false, error: "El archivo no existe." }, status: :unprocessable_entity unless File.file?(abs)
      return render json: { success: false, error: "El archivo es demasiado grande para editar desde el panel." }, status: :unprocessable_entity if File.size(abs) > MAX_FILE_SIZE
      return render json: { success: false, error: "Este tipo de archivo es solo lectura." }, status: :forbidden unless editable?(abs)

      File.write(abs, params[:content].to_s)

      render json: {
        success: true,
        path: abs,
        editable: true,
        file_type: detect_type(abs),
        last_modified: File.mtime(abs).iso8601
      }
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    def search
      query = params[:q].to_s.strip
      return render json: { success: true, results: [] } if query.blank?

      base = base_project_path
      return render json: { success: true, results: [] } if base.blank? || !Dir.exist?(base)

      include_flags = ALLOWED_EXTENSIONS.flat_map { |ext| ["--include", "*#{ext}"] }
      command = ["grep", "-RIn", "--color=never", "--max-count=1", *include_flags, query, base]
      output = IO.popen(command, err: [:child, :out], &:read)

      results = output.lines.map(&:strip).filter_map do |line|
        next if line.blank?

        parts = line.split(":", 3)
        next if parts.length < 3

        file_path, line_no, preview = parts
        next unless file_path

        {
          path: file_path,
          line: line_no.to_i,
          preview: preview.to_s.strip
        }
      end.first(50)

      render json: { success: true, results: results }
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    private

    def set_board
      @board = current_user.boards.find(params[:board_id])
    end

    def set_project_file
      @project_file = @board.project_files.find(params[:id])
    end

    def base_project_path
      @board.project_path.presence
    end

    def next_position
      (@board.project_files.maximum(:position) || -1) + 1
    end

    def build_tree
      base = base_project_path
      return [] if base.blank? || !Dir.exist?(base)

      grouped = Hash.new { |h, k| h[k] = [] }

      Dir.glob(File.join(base, "**", "*")).sort.each do |abs|
        next unless File.file?(abs)
        next unless ALLOWED_EXTENSIONS.include?(File.extname(abs).downcase)
        next if File.size(abs) > MAX_FILE_SIZE

        rel = abs.delete_prefix("#{base}/")
        dir = File.dirname(rel)
        dir = "." if dir == rel

        grouped[dir] << {
          path: abs,
          name: File.basename(abs),
          relative: rel
        }
      end

      grouped.keys.sort.map { |dir| { dir: dir, files: grouped[dir] } }
    end

    def read_payload(path)
      abs = resolve_path(path)
      raise "Invalid path" unless valid_readable_path?(abs)

      content = File.read(abs)
      is_editable = editable?(abs)
      file_type = detect_type(abs)

      {
        success: true,
        path: abs,
        content: content,
        editable: is_editable,
        file_type: file_type,
        language: language_for(abs),
        rendered_html: render_markdown(content, abs, file_type)
      }
    end

    def render_markdown(content, abs_path, file_type)
      return nil unless file_type == "markdown"

      helpers.simple_format(
        ERB::Util.html_escape(content),
        {},
        sanitize: false
      )
    end

    def valid_readable_path?(path)
      abs = resolve_path(path)
      safe_path?(abs) && File.file?(abs) && ALLOWED_EXTENSIONS.include?(File.extname(abs).downcase) && File.size(abs) <= MAX_FILE_SIZE
    rescue StandardError
      false
    end

    def safe_path?(abs)
      project_base = File.expand_path(base_project_path.to_s)
      return false if project_base.blank?

      abs == project_base || abs.start_with?("#{project_base}/")
    end

    def resolve_path(path)
      File.expand_path(path.to_s)
    end

    def editable?(path)
      EDITABLE_EXTENSIONS.include?(File.extname(path).downcase)
    end

    def detect_type(path)
      ext = File.extname(path).downcase
      return "markdown" if %w[.md .txt].include?(ext)
      return "ruby" if ext == ".rb"
      return "python" if ext == ".py"
      return "shell" if ext == ".sh"
      return "yaml" if %w[.yml .yaml].include?(ext)
      return "json" if ext == ".json"

      "text"
    end

    def language_for(path)
      case File.extname(path).downcase
      when ".md" then "markdown"
      when ".txt" then "plaintext"
      when ".rb" then "ruby"
      when ".py" then "python"
      when ".sh" then "bash"
      when ".yml", ".yaml" then "yaml"
      when ".json" then "json"
      when ".toml" then "toml"
      when ".cfg" then "ini"
      when ".env" then "bash"
      else "plaintext"
      end
    end

    def serialize_project_file(project_file)
      {
        id: project_file.id,
        file_path: project_file.file_path,
        label: project_file.label,
        display_name: project_file.display_name,
        pinned: project_file.pinned,
        position: project_file.position,
        file_type: project_file.file_type
      }
    end
  end
end
