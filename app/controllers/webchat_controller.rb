# frozen_string_literal: true

class WebchatController < ApplicationController
  before_action :require_authentication

  # GET /webchat
  # Retained as an inert notice during Safe-LAN containment.
  def show
    @task = current_user.tasks.find_by(id: params[:task_id]) if params[:task_id].present?
  end
end
