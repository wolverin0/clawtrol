# frozen_string_literal: true

module Api
  module BudgetGate
    extend ActiveSupport::Concern

    private

    def enforce_budget_gate
      return unless current_user&.over_budget?
      render json: {
        error: "budget_exceeded",
        message: "Daily or monthly spend cap reached. Raise cap or wait for next period."
      }, status: :payment_required
    end
  end
end
