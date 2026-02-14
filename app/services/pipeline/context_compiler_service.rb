# frozen_string_literal: true

module Pipeline
  class ContextCompilerService
    MANIFEST_DIR = File.expand_path("~/.openclaw/workspace/projects/manifestos")

    def initialize(task, user: nil)
      @task = task
      @user = user || task.user
      @config = TriageService.config
    end

    def call
      pipeline_cfg = pipeline_config_for(@task.pipeline_type)
      context_mode = pipeline_cfg&.dig(:context_mode)&.to_s || "template"

      context = case context_mode
      when "template"
        build_template_context
      when "template_with_manifest"
        build_template_context.merge(build_manifest_context)
      when "template_with_rag"
        build_template_context.merge(build_manifest_context).merge(build_rag_context)
      when "full_compilation"
        build_template_context.merge(build_manifest_context).merge(build_rag_context).merge(build_history_context)
      else
        build_template_context
      end

      context[:compiled_at] = Time.current.iso8601
      context[:context_mode] = context_mode

      log_entry = {
        stage: "context_compilation",
        context_mode: context_mode,
        keys: context.keys,
        manifest_found: context[:manifest].present?,
        rag_results: context[:rag]&.size || 0,
        at: Time.current.iso8601
      }

      if observation_mode?
        append_pipeline_log(@task, log_entry)
      else
        @task.update_columns(
          agent_context: context,
          pipeline_stage: "context_ready",
          pipeline_log: Array(@task.pipeline_log).push(log_entry)
        )
      end

      context
    end

    private

    def build_template_context
      board = @task.board
      {
        task: {
          id: @task.id,
          name: @task.name,
          description: clean_description(@task.description),
          tags: Array(@task.tags),
          priority: @task.priority,
          model: @task.model,
          validation_command: @task.validation_command,
          status: @task.status
        },
        board: {
          id: board&.id,
          name: board&.name
        },
        dependencies: build_dependencies_context
      }
    end

    def build_dependencies_context
      return [] unless @task.respond_to?(:dependencies)

      @task.dependencies.map do |dep|
        {
          id: dep.id,
          name: dep.name,
          status: dep.status,
          completed: dep.completed?
        }
      end
    end

    def build_manifest_context
      project_name = detect_project_name
      return {} unless project_name

      manifest = load_manifest(project_name)
      return {} unless manifest

      { manifest: manifest }
    end

    def detect_project_name
      board_name = @task.board&.name&.downcase&.strip
      return board_name if board_name.present? && manifest_exists?(board_name)

      # Check project: tag prefix
      project_tag = Array(@task.tags).find { |t| t.to_s.start_with?("project:") }
      if project_tag
        name = project_tag.sub("project:", "").strip.downcase
        return name if manifest_exists?(name)
      end

      # Try board name variations
      if board_name
        # Try kebab-case
        kebab = board_name.gsub(/\s+/, "-")
        return kebab if manifest_exists?(kebab)

        # Try snake_case
        snake = board_name.gsub(/\s+/, "_")
        return snake if manifest_exists?(snake)
      end

      nil
    end

    def manifest_exists?(name)
      return false unless name.present?
      Dir.glob(File.join(MANIFEST_DIR, "#{name}.*")).any? ||
        Dir.glob(File.join(MANIFEST_DIR, "#{name}", "*.{yml,yaml,md}")).any?
    end

    def load_manifest(name)
      # Try direct YAML file
      %w[yml yaml].each do |ext|
        path = File.join(MANIFEST_DIR, "#{name}.#{ext}")
        next unless File.exist?(path)

        begin
          return YAML.load_file(path).deep_symbolize_keys
        rescue StandardError => e
          Rails.logger.warn("[Pipeline::ContextCompiler] Failed to parse manifest #{path}: #{e.message}")
          return nil
        end
      end

      # Try markdown file
      md_path = File.join(MANIFEST_DIR, "#{name}.md")
      if File.exist?(md_path)
        content = File.read(md_path, encoding: "UTF-8")
        return { raw: content.truncate(4000) }
      end

      # Try directory with manifest inside
      dir_path = File.join(MANIFEST_DIR, name)
      if Dir.exist?(dir_path)
        manifest_file = Dir.glob(File.join(dir_path, "*.{yml,yaml}")).first
        if manifest_file
          begin
            return YAML.load_file(manifest_file).deep_symbolize_keys
          rescue StandardError
            return nil
          end
        end
      end

      nil
    rescue StandardError => e
      Rails.logger.warn("[Pipeline::ContextCompiler] Failed to load manifest for '#{name}': #{e.message}")
      nil
    end

    def build_rag_context
      query = "#{@task.name} #{@task.description.to_s.truncate(200)}"
      results = QdrantClient.new.search(query, limit: 5)
      return {} if results.empty?

      { rag: results }
    rescue StandardError => e
      Rails.logger.warn("[Pipeline::ContextCompiler] RAG search failed: #{e.message}")
      {}
    end

    def build_history_context
      recent_tasks = @task.board&.tasks
        &.where(completed: true)
        &.where.not(id: @task.id)
        &.order(completed_at: :desc)
        &.limit(10)
        &.select(:id, :name, :model, :pipeline_type, :completed_at)

      return {} unless recent_tasks&.any?

      {
        history: recent_tasks.map { |t|
          {
            id: t.id,
            name: t.name,
            model: t.model,
            pipeline_type: t.pipeline_type,
            completed_at: t.completed_at&.iso8601
          }
        }
      }
    rescue StandardError
      {}
    end

    def clean_description(desc)
      return nil if desc.blank?

      # Strip agent activity/output sections for context compilation
      text = desc.to_s
      if text.include?("## Agent Activity") || text.include?("## Agent Output")
        parts = text.split("\n\n---\n\n")
        text = parts.last if parts.size > 1
      end

      text.truncate(3000)
    end

    def pipeline_config_for(pipeline_type)
      return nil unless pipeline_type
      pipelines = @config[:pipelines] || {}
      pipelines[pipeline_type.to_sym] || pipelines[pipeline_type.to_s.to_sym]
    end

    def observation_mode?
      @config[:observation_mode] == true
    end

    def append_pipeline_log(task, entry)
      current = Array(task.pipeline_log)
      task.update_columns(pipeline_log: current.push(entry))
    end
  end
end
