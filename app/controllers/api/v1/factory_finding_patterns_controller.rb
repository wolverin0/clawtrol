# frozen_string_literal: true

module Api
  module V1
    class FactoryFindingPatternsController < BaseController
      def dismiss
        pattern = FactoryFindingPattern
          .joins(:factory_loop)
          .where(factory_loops: { user_id: current_user.id })
          .find(params[:id])

        pattern.dismiss!

        render json: {
          id: pattern.id,
          dismiss_count: pattern.dismiss_count,
          suppressed: pattern.suppressed
        }
      end
    end
  end
end
