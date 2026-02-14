# frozen_string_literal: true

# Concern for task validation and review operations:
# revalidate, start_validation, run_debate, complete_review
#
# Extracted from Api::V1::TasksController to reduce its size (-100 lines).
# Requires the host controller to define:
#   - set_task_activity_info(task)
#   - task_json(task)
module Api
  module TaskValidationManagement
    extend ActiveSupport::Concern

    # POST /api/v1/tasks/:id/revalidate
    def revalidate
      unless @task.validation_command.present?
        render json: { error: "No validation command configured" }, status: :unprocessable_entity
        return
      end

      set_task_activity_info(@task)
      ValidationRunnerService.new(@task).call

      render json: {
        task: task_json(@task),
        validation_status: @task.validation_status,
        validation_output: @task.validation_output
      }
    end

    # POST /api/v1/tasks/:id/start_validation
    def start_validation
      command = params[:command].presence || @task.validation_command
      unless command.present?
        render json: { error: "No validation command specified" }, status: :unprocessable_entity
        return
      end

      set_task_activity_info(@task)
      @task.start_review!(type: "command", config: { command: command })
      @task.update!(validation_command: command)

      RunValidationJob.perform_later(@task.id)

      render json: {
        task: task_json(@task),
        review_status: @task.review_status,
        message: "Validation started"
      }
    end

    # POST /api/v1/tasks/:id/run_debate
    def run_debate
      render json: {
        error: "Debate review is not yet implemented. Coming soon.",
        not_implemented: true
      }, status: :service_unavailable
    end

    # POST /api/v1/tasks/:id/complete_review
    def complete_review
      status = params[:status]
      result = params[:result] || {}

      unless %w[passed failed].include?(status)
        render json: { error: "Status must be 'passed' or 'failed'" }, status: :unprocessable_entity
        return
      end

      set_task_activity_info(@task)
      @task.complete_review!(status: status, result: result)

      Notification.create_for_review(@task, passed: status == "passed")

      render json: {
        task: task_json(@task),
        review_status: @task.review_status,
        review_result: @task.review_result
      }
    end
  end
end
