# frozen_string_literal: true

module Api
  module V1
    class AuditsController < BaseController
      def ingest
        report = current_user.audit_reports.create!(audit_report_params)
        interventions_updated = auto_update_interventions(report)

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

      def auto_update_interventions(report)
        updated_count = 0

        report.scores.each do |category, raw_score|
          score = raw_score.to_f
          intervention = current_user.behavioral_interventions.active.find_by(category: category)

          if intervention
            intervention.update!(current_score: score, audit_report: report)
            updated_count += 1

            baseline = intervention.baseline_score.to_f
            improved_now = (score - baseline) >= 1.0
            dropped_now = (baseline - score) >= 1.0

            previous_report = current_user.audit_reports.where.not(id: report.id).recent.first
            previous_score = previous_report&.scores&.dig(category)&.to_f
            improved_prev = !previous_score.nil? && ((previous_score - baseline) >= 1.0)

            intervention.resolve! if improved_now && improved_prev
            intervention.regress! if dropped_now
          elsif score < 5.0
            current_user.behavioral_interventions.create!(
              category: category,
              rule: "Auto-generated: #{category} score below threshold (#{score})",
              baseline_score: score,
              current_score: score,
              status: "active",
              audit_report: report
            )
            updated_count += 1
          end
        end

        updated_count
      end
    end
  end
end
