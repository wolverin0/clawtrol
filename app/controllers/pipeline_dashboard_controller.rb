# frozen_string_literal: true

# Pipeline Dashboard
# Simple view for tracking pipeline progress across pipeline_enabled tasks.
class PipelineDashboardController < ApplicationController
  # GET /pipeline
  def show
    @boards = current_user.boards.order(position: :asc)

    @filter_board_id = params[:board_id].presence
    @filter_status = params[:status].presence
    @filter_stage = params[:pipeline_stage].presence
    @filter_model = params[:routed_model].presence
    @query = params[:q].to_s.strip

    scope = current_user.tasks.pipeline_enabled.includes(:board)

    scope = scope.where(board_id: @filter_board_id) if @filter_board_id
    scope = scope.where(status: @filter_status) if @filter_status
    scope = scope.where(pipeline_stage: @filter_stage) if @filter_stage
    scope = scope.where(routed_model: @filter_model) if @filter_model

    if @query.present?
      if @query.match?(/\A\d+\z/)
        scope = scope.where(id: @query.to_i)
      else
        scope = scope.where("tasks.name ILIKE ?", "%#{@query}%")
      end
    end

    scope = scope.order(updated_at: :desc, id: :desc)

    limit = params[:limit].to_i
    limit = 200 if limit <= 0 || limit > 500
    @tasks = scope.limit(limit)

    @stage_options = Task::PIPELINE_STAGES
    @status_options = Task.statuses.keys
    @model_options = current_user.tasks.pipeline_enabled.where.not(routed_model: [nil, ""]).distinct.order(:routed_model).pluck(:routed_model)
  end
end
