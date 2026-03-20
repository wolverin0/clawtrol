# frozen_string_literal: true

class BrainDumpsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_brain_dump, only: [:triage]

  def index
    @brain_dumps = current_user.brain_dumps.order(created_at: :desc)
  end

  def create
    @brain_dump = current_user.brain_dumps.new(brain_dump_params)

    respond_to do |format|
      if @brain_dump.save
        format.turbo_stream
      else
        format.turbo_stream { render :create_error, status: :unprocessable_entity }
      end
    end
  end

  def triage
    @task = @brain_dump.triage_into_task

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_brain_dump
    @brain_dump = current_user.brain_dumps.find(params[:id])
  end

  def brain_dump_params
    params.require(:brain_dump).permit(:content, :metadata)
  end
end
