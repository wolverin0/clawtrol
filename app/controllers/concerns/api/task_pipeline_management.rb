# frozen_string_literal: true

module Api
  module TaskPipelineManagement
    extend ActiveSupport::Concern

    # POST /api/v1/tasks/:id/route_pipeline
    # Advance the task one step through the configured pipeline.
    def route_pipeline
      orchestrator = Pipeline::Orchestrator.new(@task, user: current_user)
      previous_stage = @task.pipeline_stage
      new_stage = orchestrator.process!
      @task.reload

      if new_stage.present?
        render json: {
          success: true,
          task_id: @task.id,
          previous_stage: previous_stage,
          pipeline_stage: @task.pipeline_stage,
          pipeline_type: @task.pipeline_type,
          routed_model: @task.routed_model
        }
      else
        render json: {
          success: false,
          task_id: @task.id,
          pipeline_stage: @task.pipeline_stage,
          error: "No pipeline advancement available for current state"
        }, status: :unprocessable_entity
      end
    end

    # GET /api/v1/tasks/:id/pipeline_info
    # Returns current pipeline progress and configuration for the task.
    def pipeline_info
      render json: {
        task_id: @task.id,
        pipeline: {
          enabled: @task.pipeline_enabled,
          stage: @task.pipeline_stage,
          type: @task.pipeline_type,
          routed_model: @task.routed_model,
          has_compiled_prompt: @task.compiled_prompt.present?,
          log_entries: Array(@task.pipeline_log).size
        },
        available_pipelines: Pipeline::TriageService.config.fetch(:pipelines, {}).keys.map(&:to_s)
      }
    end
  end
end
