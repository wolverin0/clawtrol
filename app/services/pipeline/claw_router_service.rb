# frozen_string_literal: true

require "erb"

module Pipeline
  class ClawRouterService
    TEMPLATE_DIR = Rails.root.join("config", "prompt_templates")

    def initialize(task)
      @task = task
      @config = TriageService.config
    end

    def call
      pipeline_type = @task.pipeline_type
      pipeline_cfg = pipeline_config_for(pipeline_type)

      model = select_model(pipeline_cfg)
      prompt = build_prompt(pipeline_cfg)

      log_entry = {
        stage: "routing",
        pipeline_type: pipeline_type,
        selected_model: model,
        prompt_length: prompt&.length || 0,
        prompt_template: pipeline_cfg&.dig(:prompt_template)&.to_s,
        at: Time.current.iso8601
      }

      if observation_mode?
        append_pipeline_log(@task, log_entry)
      else
        @task.update_columns(
          routed_model: model,
          compiled_prompt: prompt,
          pipeline_stage: "routed",
          pipeline_log: Array(@task.pipeline_log).push(log_entry)
        )
      end

      { model: model, prompt_length: prompt&.length || 0 }
    end

    private

    def select_model(pipeline_cfg)
      # User-set model always wins
      return @task.model if @task.model.present?

      # Planning tasks must never route to low tiers (e.g. glm).
      # Snake requirement: minimum gemini3 pro preview or codex; default to codex.
      return "codex" if planning_task?

      # Nightshift uses mission model if available
      if @task.pipeline_type == "nightshift" && @task.respond_to?(:nightshift_mission)
        mission_model = @task.nightshift_mission&.model
        return mission_model if mission_model.present?
      end

      # Tier from pipeline config
      tier_name = pipeline_cfg&.dig(:model_tier)&.to_s || "free"
      resolve_model_from_tier(tier_name)
    end

    def planning_task?
      normalized_tags = Array(@task.tags).map { |t| t.to_s.downcase.strip }
      return true if normalized_tags.include?("planning")

      @task.name.to_s.start_with?("[Planning]")
    end

    def resolve_model_from_tier(tier_name)
      tiers = @config[:model_tiers] || {}
      tier = tiers[tier_name.to_sym]
      return Task::DEFAULT_MODEL unless tier

      models = Array(tier[:models])

      # Pick first available model in tier
      available = models.find { |m| model_available?(m) }
      return available if available

      # Fallback to next tier
      fallback_tier = tier[:fallback]&.to_s
      return Task::DEFAULT_MODEL if fallback_tier.blank? || fallback_tier == "null"

      resolve_model_from_tier(fallback_tier)
    end

    def model_available?(model_name)
      return true unless defined?(ModelLimit)

      user = @task.user
      return true unless user

      limit = ModelLimit.find_by(user: user, name: model_name)
      return true unless limit

      # If limit was recorded more than 2 hours ago, consider it cleared
      return true if limit.recorded_at.present? && limit.recorded_at < 2.hours.ago

      false
    rescue StandardError
      true
    end

    def build_prompt(pipeline_cfg)
      template_name = pipeline_cfg&.dig(:prompt_template)&.to_s
      return build_fallback_prompt unless template_name.present?

      template_path = TEMPLATE_DIR.join("#{template_name}.md.erb")
      return build_fallback_prompt unless File.exist?(template_path)

      context = @task.agent_context || {}
      context = context.deep_symbolize_keys if context.respond_to?(:deep_symbolize_keys)

      # Build template binding variables
      task = context[:task] || {}
      board = context[:board] || {}
      manifest = context[:manifest]
      dependencies = context[:dependencies] || []
      history = context[:history] || []
      rag = context[:rag] || []

      template_content = File.read(template_path, encoding: "UTF-8")
      erb = ERB.new(template_content, trim_mode: "-")

      # Create a clean binding with the template variables
      binding_obj = TemplateBinding.new(
        task: task,
        board: board,
        manifest: manifest,
        dependencies: dependencies,
        history: history,
        rag: rag,
        raw_task: @task
      )

      erb.result(binding_obj.get_binding)
    rescue StandardError => e
      Rails.logger.warn("[Pipeline::ClawRouterService] Template rendering failed: #{e.class}: #{e.message}")
      build_fallback_prompt
    end

    def build_fallback_prompt
      parts = []
      parts << "# Task: #{@task.name}"
      parts << ""

      desc = @task.description.to_s
      if desc.present?
        parts << "## Description"
        parts << desc.truncate(3000)
        parts << ""
      end

      if @task.validation_command.present?
        parts << "## Validation"
        parts << "Run this command to verify your work:"
        parts << "```bash"
        parts << @task.validation_command
        parts << "```"
        parts << ""
      end

      parts << "## Guidelines"
      parts << "- Make minimal, focused changes"
      parts << "- Test your changes before completing"
      parts << "- Report what you achieved and what remains"

      parts.join("\n")
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

    # Clean binding class for ERB templates
    class TemplateBinding
      def initialize(task:, board:, manifest:, dependencies:, history:, rag:, raw_task:)
        @task = task
        @board = board
        @manifest = manifest
        @dependencies = dependencies
        @history = history
        @rag = rag
        @raw_task = raw_task
      end

      def get_binding
        binding
      end

      private

      attr_reader :task, :board, :manifest, :dependencies, :history, :rag, :raw_task
    end
  end
end
