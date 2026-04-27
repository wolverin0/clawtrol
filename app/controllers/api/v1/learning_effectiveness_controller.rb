# frozen_string_literal: true

module Api
  module V1
    class LearningEffectivenessController < BaseController
      # GET /api/v1/learning_effectiveness
      #
      # Returns aggregated effectiveness data per learning entry.
      # Used by the Opus reflector script to score and graduate learnings.
      #
      # Params:
      #   days (optional) - filter to recent N days (default: 60, max: 365)
      #   entry_id (optional) - filter to specific learning entry
      def index
        days = [(params[:days] || 60).to_i, 1].max
        days = [days, 365].min
        scope = LearningEffectiveness.recent(days)

        if params[:entry_id].present?
          scope = scope.for_learning(params[:entry_id])
        end

        stats = scope.aggregated_stats.map do |record|
          total = record.total_surfaced.to_i
          successes = record.success_count.to_i
          {
            learning_entry_id: record.learning_entry_id,
            learning_title: record.learning_title,
            total_surfaced: total,
            success_count: successes,
            success_rate: total > 0 ? (successes.to_f / total).round(3) : nil,
            avg_effectiveness: record.avg_effectiveness&.round(3),
            last_surfaced_at: record.last_surfaced_at
          }
        end

        render json: { data: stats, period_days: days }
      end
    end
  end
end
