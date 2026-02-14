# frozen_string_literal: true

module Api
  module TaskPipelineManagement
    extend ActiveSupport::Concern

    # POST /api/v1/tasks/:id/route_pipeline
    # Advance the task through its ClawRouter pipeline
    def route_pipeline
      router = ClawRouterService.new(@task)

      if router.route!
        @task.reload
        render json: {
          success: true,
          task_id: @task.id,
          pipeline_stage: @task.pipeline_stage,
          pipeline_type: @task.state_data&.dig("pipeline_type"),
          model: @task.model,
          info: router.pipeline_info
        }
      else
        render json: {
          success: false,
          task_id: @task.id,
          pipeline_stage: @task.pipeline_stage,
          error: "Cannot advance pipeline (may be at end or validation failed)",
          errors: @task.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # GET /api/v1/tasks/:id/pipeline_info
    # Returns current pipeline progress and configuration for the task.
    def pipeline_info
      router = ClawRouterService.new(@task)
      info = router.pipeline_info

      # Add workflow checklist for the current stage
      pipeline_type = @task.state_data&.dig("pipeline_type") || router.detect_pipeline_type
      workflow_name = case pipeline_type
                      when "security_audit" then "security_audit"
                      when "bug_fix" then "bug_fix"
                      when "feature" then "feature_implementation"
                      when "refactor" then "refactor"
                      else nil
                      end
      checklist = workflow_name ? WorkflowTemplateLoader.phase_checklist(workflow_name, @task.pipeline_stage) : nil

      render json: {
        task_id: @task.id,
        pipeline: info,
        checklist: checklist,
        available_pipelines: PipelineConfig.pipeline_types,
        available_workflows: WorkflowTemplateLoader.available_templates
      }
    end
  end
end
