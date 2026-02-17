# frozen_string_literal: true

class ZerobitchController < ApplicationController
  before_action :require_authentication

  # GET /zerobitch
  def index; end

  # GET /zerobitch/agents/new
  def new_agent; end

  # POST /zerobitch/agents
  def create_agent
    redirect_to zerobitch_path, notice: "Agent creation stub ready."
  end

  # GET /zerobitch/agents/:id
  def show_agent
    @agent_id = params[:id]
  end

  # DELETE /zerobitch/agents/:id
  def destroy_agent
    redirect_to zerobitch_path, notice: "Agent deletion stub ready for #{params[:id]}."
  end

  # POST /zerobitch/agents/:id/start
  def start_agent
    redirect_to zerobitch_agent_path(params[:id]), notice: "Start stub ready for #{params[:id]}."
  end

  # POST /zerobitch/agents/:id/stop
  def stop_agent
    redirect_to zerobitch_agent_path(params[:id]), notice: "Stop stub ready for #{params[:id]}."
  end

  # POST /zerobitch/agents/:id/restart
  def restart_agent
    redirect_to zerobitch_agent_path(params[:id]), notice: "Restart stub ready for #{params[:id]}."
  end

  # POST /zerobitch/agents/:id/task
  def send_task
    redirect_to zerobitch_agent_tasks_path(params[:id]), notice: "Task dispatch stub ready for #{params[:id]}."
  end

  # GET /zerobitch/agents/:id/logs
  def logs
    @agent_id = params[:id]
  end

  # GET /zerobitch/agents/:id/tasks
  def task_history
    @agent_id = params[:id]
  end
end
