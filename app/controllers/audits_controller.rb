# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :require_authentication

  def index
    @tab = params[:tab] == "interventions" ? "interventions" : "trends"

    if @tab == "trends"
      load_trends_data
    else
      load_interventions_data
    end
  end

  def interventions
    redirect_to audits_path(tab: "interventions")
  end

  private

  def load_trends_data
    @daily_reports = current_user.audit_reports.daily.order(:created_at).last(30)
    @weekly_reports = current_user.audit_reports.weekly.order(:created_at).last(12)
    @latest = current_user.audit_reports.recent.first

    @chart_data = {
      labels: @daily_reports.map { |r| r.created_at.strftime("%m/%d") },
      scores: @daily_reports.map(&:overall_score),
      categories: build_category_data(@daily_reports),
      anti_patterns: @daily_reports.map { |r| r.anti_pattern_counts.values.sum }
    }

    return unless @weekly_reports.length >= 2

    current_week = @weekly_reports.last
    prev_week = @weekly_reports[-2]
    @week_delta = (current_week.overall_score - prev_week.overall_score).round(1)
  end

  def load_interventions_data
    @interventions = current_user.behavioral_interventions.order(created_at: :desc)
    @active_count = @interventions.active.count
    @resolved_count = @interventions.resolved.count
    @regressed_count = @interventions.regressed.count
  end

  def build_category_data(reports)
    return {} if reports.empty?

    categories = reports.flat_map { |r| r.scores.keys }.uniq
    categories.each_with_object({}) do |cat, hash|
      hash[cat] = reports.map { |r| r.scores[cat] || 0 }
    end
  end
end
