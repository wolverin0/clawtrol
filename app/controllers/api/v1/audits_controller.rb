# frozen_string_literal: true

module Api
  module V1
    class AuditsController < BaseController
      def ingest
        report = current_user.audit_reports.create!(audit_report_params)
        interventions_updated = BehavioralInterventionUpdaterService.call(user: current_user, report: report)

        render json: { id: report.id, interventions_updated: interventions_updated }, status: :created
      end

      def latest
        report = current_user.audit_reports.recent.first

        if report.nil?
          render json: { error: "Not found" }, status: :not_found
          return
        end

        render json: report.slice(
          "scores",
          "anti_pattern_counts",
          "worst_moments",
          "overall_score",
          "report_type",
          "created_at"
        )
      end

      private

      def audit_report_params
        params.permit(
          :report_type,
          :overall_score,
          :report_path,
          :messages_analyzed,
          :session_files_analyzed,
          scores: {},
          anti_pattern_counts: {},
          worst_moments: []
        )
      end
    end
  end
end
