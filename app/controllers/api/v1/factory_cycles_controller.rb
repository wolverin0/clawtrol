# frozen_string_literal: true

module Api
  module V1
    class FactoryCyclesController < BaseController
      # POST /api/v1/factory/loops/:loop_id/cycles
      def create
        loop = current_user.factory_loops.find(params[:loop_id])

        cycle_log = nil
        FactoryLoop.transaction do
          loop.lock!
          next_cycle = (loop.factory_cycle_logs.maximum(:cycle_number) || 0) + 1
          cycle_log = loop.factory_cycle_logs.create!(
            cycle_number: next_cycle,
            status: params[:status].presence || "running",
            started_at: Time.current,
            trigger: "cron"
          )
        end

        render json: { id: cycle_log.id, cycle_number: cycle_log.cycle_number, status: cycle_log.status }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Factory loop not found" }, status: :not_found
      end

      # POST /api/v1/factory/cycles/:id/complete
      def complete
        cycle_log = FactoryCycleLog
          .joins(:factory_loop)
          .where(factory_loops: { user_id: current_user.id })
          .find(params[:id])

        unless %w[pending running].include?(cycle_log.status)
          return render json: { error: "Cycle already finalized (#{cycle_log.status})" }, status: :unprocessable_entity
        end

        status = params[:status]
        unless %w[completed failed].include?(status)
          return render json: { error: "Invalid status. Must be 'completed' or 'failed'" }, status: :unprocessable_entity
        end

        FactoryEngineService.new.record_cycle_result(
          cycle_log,
          status: status,
          summary: params[:summary],
          input_tokens: params[:input_tokens]&.to_i,
          output_tokens: params[:output_tokens]&.to_i,
          model_used: params[:model_used]
        )

        render json: {
          success: true,
          cycle_log_id: cycle_log.id,
          status: cycle_log.reload.status,
          loop_status: cycle_log.factory_loop.reload.status
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Cycle log not found" }, status: :not_found
      end
    end
  end
end
