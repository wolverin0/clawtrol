# frozen_string_literal: true

class FactoryLoopsController < ApplicationController
  before_action :set_loop, only: [ :show, :update, :destroy, :play, :pause, :stop, :metrics, :findings ]

  def index
    loops = current_user.factory_loops.ordered.includes(:factory_cycle_logs)

    render json: loops.map { |loop|
      loop.as_json(only: [
        :id, :name, :slug, :description, :icon, :status, :interval_ms,
        :model, :fallback_model, :system_prompt, :workspace_path, :work_branch,
        :total_cycles, :total_errors, :avg_cycle_duration_ms, :last_cycle_at, :last_error_message,
        :config
      ])
    }
  end

  def show
    recent_logs = @loop.factory_cycle_logs.order(started_at: :desc).limit(10)

    render json: @loop.as_json(only: [
      :id, :name, :slug, :description, :icon, :status, :interval_ms,
      :model, :fallback_model, :system_prompt, :workspace_path, :work_branch,
      :total_cycles, :total_errors, :avg_cycle_duration_ms, :last_cycle_at, :last_error_message,
      :config, :state, :metrics
    ]).merge(
      recent_logs: recent_logs.as_json(only: [ :id, :status, :summary, :started_at, :finished_at, :duration_ms ])
    )
  end

  def create
    loop = current_user.factory_loops.new(factory_loop_params)

    if loop.save
      render json: loop, status: :created
    else
      render json: { errors: loop.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @loop.update(factory_loop_params)
      render json: @loop
    else
      render json: { errors: @loop.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @loop.destroy
    render json: { success: true }
  end

  def play
    @loop.play!
    render json: { success: true, status: @loop.status }
  end

  def pause
    @loop.pause!
    render json: { success: true, status: @loop.status }
  end

  def stop
    @loop.stop!
    render json: { success: true, status: @loop.status }
  end

  def metrics
    render json: (@loop.metrics.is_a?(Hash) ? @loop.metrics : {}).merge(
      id: @loop.id,
      status: @loop.status,
      total_cycles: @loop.total_cycles,
      total_errors: @loop.total_errors,
      avg_cycle_duration_ms: @loop.avg_cycle_duration_ms,
      last_cycle_at: @loop.last_cycle_at
    )
  end

  def findings
    render json: @loop.factory_finding_patterns.order(updated_at: :desc).limit(100)
  end

  private

  def set_loop
    @loop = current_user.factory_loops.find(params[:id])
  end

  def factory_loop_params
    attrs = [
      :name, :description, :icon, :model, :fallback_model, :interval_ms,
      :system_prompt, :workspace_path, :work_branch, :slug,
      config: {}
    ]

    if params[:factory_loop].present?
      params.require(:factory_loop).permit(*attrs)
    else
      params.permit(*attrs)
    end
  end
end
