# frozen_string_literal: true

class DecisionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @tasks = Task.where(user: current_user, status: :needs_decision).order(created_at: :asc)
  end

  def update
    @task = current_user.tasks.find(params[:id])
    action = params[:action_type]

    case action
    when "retry"
      @task.update!(status: :up_next, consecutive_failures: 0)
      flash[:notice] = "Task requeued for retry"
    when "skip"
      @task.update!(status: :done, consecutive_failures: 0)
      flash[:notice] = "Task marked as done"
    when "stop"
      @task.update!(status: :archived, consecutive_failures: 0)
      flash[:notice] = "Task archived"
    else
      flash[:alert] = "Invalid action"
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to decisions_path }
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Task not found"
    redirect_to decisions_path
  end
end
