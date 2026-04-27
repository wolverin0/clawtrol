# frozen_string_literal: true

module Api
  module V1
    class PipelineController < BaseController
      # GET /api/v1/pipeline/status
      def status
        tasks = current_user.tasks.where(pipeline_enabled: true)

        stage_counts = tasks.group(:pipeline_stage).count
        model_counts = tasks.where.not(routed_model: nil).group(:routed_model).count
        type_counts = tasks.where.not(pipeline_type: nil).group(:pipeline_type).count

        recent = tasks.where.not(pipeline_stage: nil)
                      .order(updated_at: :desc)
                      .limit(10)
                      .select(:id, :name, :pipeline_stage, :pipeline_type, :routed_model, :updated_at)

        config = Pipeline::TriageService.config
        observation_mode = config[:observation_mode] == true

        render json: {
          observation_mode: observation_mode,
          total_pipeline_tasks: tasks.count,
          by_stage: stage_counts,
          by_model: model_counts,
          by_type: type_counts,
          recent: recent.map { |t|
            {
              id: t.id,
              name: t.name,
              stage: t.pipeline_stage,
              type: t.pipeline_type,
              model: t.routed_model,
              updated_at: t.updated_at.iso8601
            }
          }
        }
      end

      # POST /api/v1/pipeline/enable_board/:board_id
      def enable_board
        board = current_user.boards.find(params[:board_id])
        board.update!(pipeline_enabled: true)

        # Enable pipeline on all existing up_next tasks
        count = board.tasks.where(status: :up_next, pipeline_enabled: false).update_all(pipeline_enabled: true)

        render json: { success: true, board: board.name, tasks_enabled: count }
      end

      # POST /api/v1/pipeline/disable_board/:board_id
      def disable_board
        board = current_user.boards.find(params[:board_id])
        board.update!(pipeline_enabled: false)

        render json: { success: true, board: board.name }
      end

      # GET /api/v1/pipeline/task/:id/log
      def task_log
        task = current_user.tasks.find(params[:id])

        render json: {
          task_id: task.id,
          name: task.name,
          pipeline_stage: task.pipeline_stage,
          pipeline_type: task.pipeline_type,
          routed_model: task.routed_model,
          pipeline_enabled: task.pipeline_enabled,
          log: task.pipeline_log || []
        }
      end

      # POST /api/v1/pipeline/reprocess/:id
      def reprocess
        task = current_user.tasks.find(params[:id])

        task.update_columns(
          pipeline_stage: "unstarted",
          pipeline_type: nil,
          routed_model: nil,
          compiled_prompt: nil,
          agent_context: nil
        )

        PipelineProcessorJob.perform_later(task.id)

        render json: { success: true, task_id: task.id, message: "Pipeline reset and reprocessing enqueued" }
      end
    end
  end
end
