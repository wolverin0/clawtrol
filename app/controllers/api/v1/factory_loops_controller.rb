module Api
  module V1
    class FactoryLoopsController < BaseController
      before_action :set_loop, only: [ :show, :update, :destroy, :play, :pause, :stop, :metrics ]

      def index
        loops = FactoryLoop.by_status(params[:status]).ordered
        render json: loops
      end

      def show
        render json: @loop.as_json.merge(
          recent_cycles: @loop.factory_cycle_logs.recent.limit(10)
        )
      end

      def create
        loop = FactoryLoop.new(factory_loop_params)
        if loop.save
          render json: loop, status: :created
        else
          render json: { errors: loop.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @loop.update(factory_loop_params)
          render json: @loop
        else
          render json: { errors: @loop.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @loop.destroy
        render json: { success: true }
      end

      def play
        @loop.play!
        render json: { success: true, status: @loop.status }
      end

      def pause
        @loop.pause!
        render json: { success: true, status: @loop.status }
      end

      def stop
        @loop.stop!
        render json: { success: true, status: @loop.status, state: @loop.state }
      end

      def metrics
        render json: {
          id: @loop.id,
          total_cycles: @loop.total_cycles,
          total_errors: @loop.total_errors,
          avg_cycle_duration_ms: @loop.avg_cycle_duration_ms,
          metrics: @loop.metrics,
          last_cycle_at: @loop.last_cycle_at,
          status: @loop.status
        }
      end

      private

      def set_loop
        @loop = FactoryLoop.find(params[:id])
      end

      def factory_loop_params
        params.permit(
          :name, :slug, :description, :icon, :status, :interval_ms, :model,
          :fallback_model, :system_prompt, :openclaw_cron_id, :openclaw_session_key,
          :last_cycle_at, :last_error_at, :last_error_message, :total_cycles,
          :total_errors, :avg_cycle_duration_ms,
          state: {}, config: {}, metrics: {}
        )
      end
    end
  end
end
