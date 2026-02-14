# frozen_string_literal: true

module Api
  module V1
    class FactoryCyclesController < BaseController
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
