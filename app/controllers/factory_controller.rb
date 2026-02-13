class FactoryController < ApplicationController
  skip_forgery_protection only: [ :create, :play, :pause, :stop ]

  def index
    @loops = FactoryLoop.ordered
  end

  def create
    loop = FactoryLoop.new(factory_loop_params)
    if loop.save
      redirect_to factory_path, notice: "Factory loop created"
    else
      redirect_to factory_path, alert: loop.errors.full_messages.join(", ")
    end
  end

  def play
    loop = FactoryLoop.find(params[:id])
    loop.play!
    render json: { success: true, status: loop.status }
  end

  def pause
    loop = FactoryLoop.find(params[:id])
    loop.pause!
    render json: { success: true, status: loop.status }
  end

  def stop
    loop = FactoryLoop.find(params[:id])
    loop.stop!
    render json: { success: true, status: loop.status }
  end

  private

  def factory_loop_params
    params.require(:factory_loop).permit(:name, :slug, :description, :icon, :interval_ms, :model, :fallback_model, :system_prompt)
  end
end
