class FactoryController < ApplicationController
  skip_forgery_protection only: [ :create, :update, :destroy, :play, :pause, :stop, :bulk_play, :bulk_pause ]

  def index
    @loops = FactoryLoop.ordered
  end

  def create
    loop = FactoryLoop.new(factory_loop_params)
    if loop.save
      respond_to do |format|
        format.html { redirect_to factory_path, notice: "Factory loop created" }
        format.json { render json: { success: true, id: loop.id, name: loop.name } }
      end
    else
      respond_to do |format|
        format.html { redirect_to factory_path, alert: loop.errors.full_messages.join(", ") }
        format.json { render json: { success: false, error: loop.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def update
    loop = FactoryLoop.find(params[:id])
    if loop.update(factory_loop_params)
      respond_to do |format|
        format.html { redirect_to factory_path, notice: "Factory loop updated" }
        format.json { render json: { success: true, id: loop.id } }
      end
    else
      respond_to do |format|
        format.html { redirect_to factory_path, alert: loop.errors.full_messages.join(", ") }
        format.json { render json: { success: false, error: loop.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    loop = FactoryLoop.find(params[:id])
    loop.destroy
    respond_to do |format|
      format.html { redirect_to factory_path, notice: "Factory loop deleted" }
      format.json { render json: { success: true } }
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

  def bulk_play
    ids = params[:ids] || []
    FactoryLoop.where(id: ids).find_each(&:play!)
    render json: { success: true }
  end

  def bulk_pause
    FactoryLoop.where(status: :playing).find_each(&:pause!)
    render json: { success: true }
  end

  private

  def factory_loop_params
    params.require(:factory_loop).permit(:name, :slug, :description, :icon, :interval_ms, :model, :fallback_model, :system_prompt, config: {}, state: {})
  end
end
