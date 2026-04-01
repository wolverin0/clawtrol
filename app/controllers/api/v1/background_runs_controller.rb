# frozen_string_literal: true

module Api
  module V1
    class BackgroundRunsController < BaseController
      before_action :set_run, only: [:show, :update]

      # GET /api/v1/background_runs
      def index
        runs = current_user.background_runs.recent
        runs = runs.where(status: params[:status]) if params[:status].present?
        runs = runs.where(run_type: params[:type]) if params[:type].present?
        runs = runs.today if params[:today].present?
        render json: runs.limit(params[:limit]&.to_i || 50)
      end

      # GET /api/v1/background_runs/:id
      def show
        render json: @run.as_json(include: {
          task: { only: [:id, :name, :status] },
          openclaw_flow: { only: [:id, :flow_id, :status] }
        })
      end

      # POST /api/v1/background_runs/sync
      def sync
        run = current_user.background_runs.find_or_initialize_by(run_id: params[:run_id])
        run.assign_attributes(sync_params)

        # Auto-link to task via session_key
        if run.task_id.nil? && run.session_key.present?
          matching = current_user.tasks.where(agent_session_key: run.session_key).first
          run.task = matching if matching
        end

        # Auto-link to flow
        if run.openclaw_flow_id.nil? && run.session_key.present?
          matching_flow = current_user.openclaw_flows.where(session_key: run.session_key).first
          run.openclaw_flow = matching_flow if matching_flow
        end

        # Calculate duration
        if run.started_at && run.completed_at && run.duration_seconds.nil?
          run.duration_seconds = (run.completed_at - run.started_at).to_i
        end

        if run.save
          render json: { success: true, run: run }
        else
          render json: { error: run.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/background_runs/:id
      def update
        if @run.update(update_params)
          # Auto-calculate duration on completion
          if @run.completed_at && @run.started_at && @run.duration_seconds.nil?
            @run.update_column(:duration_seconds, (@run.completed_at - @run.started_at).to_i)
          end
          render json: { success: true, run: @run }
        else
          render json: { error: @run.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/background_runs/stats
      def stats
        today_runs = current_user.background_runs.today
        render json: {
          today: {
            total: today_runs.count,
            running: today_runs.running.count,
            completed: today_runs.completed.count,
            failed: today_runs.failed.count,
            by_type: today_runs.group(:run_type).count,
            total_tokens: today_runs.sum(:tokens_in) + today_runs.sum(:tokens_out),
            total_cost: today_runs.sum(:cost_usd)&.round(4)
          }
        }
      end

      private

      def set_run
        @run = current_user.background_runs.find(params[:id])
      end

      def sync_params
        params.permit(:run_type, :status, :model, :agent_id, :session_key, :label,
                      :trigger, :error_message, :summary, :tokens_in, :tokens_out,
                      :cost_usd, :duration_seconds, :started_at, :completed_at,
                      :task_id, :openclaw_flow_id, metadata: {})
      end

      def update_params
        params.permit(:status, :error_message, :summary, :tokens_in, :tokens_out,
                      :cost_usd, :duration_seconds, :completed_at)
      end
    end
  end
end
