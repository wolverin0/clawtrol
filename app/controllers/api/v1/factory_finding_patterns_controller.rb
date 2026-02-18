# frozen_string_literal: true

module Api
  module V1
    class FactoryFindingPatternsController < BaseController
      before_action :set_pattern

      def accept
        @pattern.accept!

        render json: {
          id: @pattern.id,
          review_state: @pattern.review_state,
          accepted: @pattern.has_attribute?(:accepted) ? @pattern.accepted : false,
          suppressed: @pattern.suppressed
        }
      end

      def dismiss
        @pattern.dismiss!

        render json: {
          id: @pattern.id,
          review_state: @pattern.review_state,
          dismiss_count: @pattern.dismiss_count,
          accepted: @pattern.has_attribute?(:accepted) ? @pattern.accepted : false,
          suppressed: @pattern.suppressed
        }
      end

      private

      def set_pattern
        @pattern = FactoryFindingPattern
          .joins(:factory_loop)
          .where(factory_loops: { user_id: current_user.id })
          .find(params[:id])
      end
    end
  end
end
