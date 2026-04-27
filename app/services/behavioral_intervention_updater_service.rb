# frozen_string_literal: true

class BehavioralInterventionUpdaterService
  def self.call(user:, report:)
    new(user, report).call
  end

  def initialize(user, report)
    @user = user
    @report = report
  end

  def call
    return 0 unless @report.scores.is_a?(Hash)

    updated_count = 0

    @report.scores.each do |category, raw_score|
      score = raw_score.to_f
      intervention = @user.behavioral_interventions.active.find_by(category: category)

      if intervention
        intervention.update!(current_score: score, audit_report: @report)
        updated_count += 1

        baseline = intervention.baseline_score.to_f
        improved_now = (score - baseline) >= 1.0
        dropped_now = (baseline - score) >= 1.0

        previous_report = @user.audit_reports.where.not(id: @report.id).recent.first
        previous_score = previous_report&.scores&.dig(category)&.to_f
        improved_prev = !previous_score.nil? && ((previous_score - baseline) >= 1.0)

        if improved_now && improved_prev
          intervention.resolve!
        elsif dropped_now
          intervention.regress!
        end
      elsif score < 5.0
        @user.behavioral_interventions.create!(
          category: category,
          rule: "Auto-generated: #{category} score below threshold (#{score})",
          baseline_score: score,
          current_score: score,
          status: "active",
          audit_report: @report
        )
        updated_count += 1
      end
    end

    updated_count
  end
end
