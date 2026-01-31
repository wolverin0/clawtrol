class Boards::TasksController < ApplicationController
  before_action :set_board
  before_action :set_task, only: [:show, :edit, :update, :destroy]

  def show
    render layout: false
  end

  def new
    @task = @board.tasks.new(user: current_user)
    render layout: false
  end

  def create
    @task = @board.tasks.new(task_params)
    @task.user = current_user
    @task.status ||= :inbox
    @task.activity_source = "web"

    if @task.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to board_path(@board), notice: "Task created." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :new, status: :unprocessable_entity, layout: false }
        format.html { render :new, status: :unprocessable_entity, layout: false }
      end
    end
  end

  def edit
    render layout: false
  end

  def update
    @task.activity_source = "web"
    if @task.update(task_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to board_path(@board), notice: "Task updated." }
      end
    else
      render :edit, status: :unprocessable_entity, layout: false
    end
  end

  def destroy
    @status = @task.status
    @task.activity_source = "web"
    @task.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to board_path(@board), notice: "Task deleted." }
    end
  end

  private

  def set_board
    @board = current_user.boards.find(params[:board_id])
  end

  def set_task
    @task = @board.tasks.find(params[:id])
  end

  def task_params
    permitted = params.require(:task).permit(:name, :title, :description, :priority, :status, :blocked, :due_date, :completed, tags: [])
    # Allow 'title' as alias for 'name'
    permitted[:name] = permitted.delete(:title) if permitted[:title].present? && permitted[:name].blank?
    permitted
  end
end
