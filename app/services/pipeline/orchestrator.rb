# frozen_string_literal: true

module Pipeline
  class Orchestrator
    MAX_ITERATIONS = 5

    def initialize(task, user: nil)
      @task = task
      @user = user || task.user
      @config = TriageService.config
    end

    # Advance the task one step through the pipeline.
    # Returns the new pipeline_stage or nil if no advancement occurred.
    def process!
      return nil unless pipeline_applicable?

      case @task.pipeline_stage
      when nil, "", "unstarted"
        triage!
      when "triaged"
        compile_context!
      when "context_ready"
        route!
      when "routed"
        # Already routed, ready for execution
        nil
      when "executing"
        # In progress, handled by outcome webhook
        nil
      when "completed", "failed"
        # Terminal states
        nil
      else
        Rails.logger.warn("[Pipeline::Orchestrator] Unknown stage '#{@task.pipeline_stage}' for task ##{@task.id}")
        nil
      end
    end

    # Run full pipeline from current stage to routed (or failure).
    # Used by PipelineProcessorJob for async processing.
    def process_to_completion!
      iterations = 0
      while iterations < MAX_ITERATIONS
        result = process!
        break if result.nil?
        break if %w[routed executing completed failed].include?(@task.reload.pipeline_stage)
        iterations += 1
      end
      @task.reload.pipeline_stage
    end

    def ready_for_execution?
      @task.pipeline_stage == "routed" &&
        @task.routed_model.present? &&
        @task.compiled_prompt.present?
    end

    private

    def pipeline_applicable?
      return false unless @task.pipeline_enabled?
      return false if @task.pipeline_stage.in?(%w[completed failed])
      true
    end

    def triage!
      result = TriageService.new(@task).call
      return nil unless result

      @task.reload
      observation_mode? ? nil : @task.pipeline_stage
    end

    def compile_context!
      ContextCompilerService.new(@task, user: @user).call
      @task.reload
      observation_mode? ? nil : @task.pipeline_stage
    end

    def route!
      ClawRouterService.new(@task).call
      @task.reload
      observation_mode? ? nil : @task.pipeline_stage
    end

    def observation_mode?
      @config[:observation_mode] == true
    end
  end
end
