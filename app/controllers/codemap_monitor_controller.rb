# frozen_string_literal: true

class CodemapMonitorController < ApplicationController
  before_action :require_authentication

  def index
    @focus_task_id = params[:task_id].to_i if params[:task_id].present?
    @tasks = codemap_tasks
  end

  private

  def codemap_tasks
    scope = current_user.tasks.not_archived.includes(:board)
    statuses = Task.statuses.values_at("in_progress", "in_review", "up_next")

    scope
      .where("assigned_to_agent = :yes OR agent_session_id IS NOT NULL OR status IN (:statuses)", yes: true, statuses: statuses)
      .order(updated_at: :desc)
      .limit(24)
  end
end
