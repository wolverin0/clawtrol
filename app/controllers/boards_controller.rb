class BoardsController < ApplicationController
  before_action :set_board, only: [:show, :update, :destroy, :update_task_status, :archived]

  def index
    # Redirect to the first board
    @board = current_user.boards.first
    if @board
      redirect_to board_path(@board)
    else
      # Create a default board if none exists
      @board = current_user.boards.create!(name: "Personal", icon: "📋", color: "gray")
      redirect_to board_path(@board)
    end
  end

  def show
    @board_page = true
    session[:last_board_id] = @board.id
    
    # For aggregator boards, show tasks from ALL boards (not archived)
    if @board.aggregator?
      @tasks = current_user.boards.where(is_aggregator: false).flat_map(&:tasks).reject { |t| t.status == "archived" }
      @tasks = Task.where(id: @tasks.map(&:id)).includes(:user, :board)
      @is_aggregator = true
    else
      @tasks = @board.tasks.not_archived.includes(:user)
      @is_aggregator = false
    end

    # Filter by tag if specified
    if params[:tag].present?
      @tasks = @tasks.where("? = ANY(tags)", params[:tag])
      @current_tag = params[:tag]
    end

    # Group tasks by status
    # Active columns: sort by position (drag order)
    # Completed columns: sort by most recently updated (newest first)
    # Note: reorder() is required to override the default_scope ordering
    @columns = {
      inbox: @tasks.inbox.reorder(position: :asc),
      up_next: @tasks.up_next.reorder(position: :asc),
      in_progress: @tasks.in_progress.reorder(position: :asc),
      in_review: @tasks.in_review.reorder(updated_at: :desc),
      done: @tasks.done.reorder(completed_at: :desc, updated_at: :desc)
    }

    # Get all unique tags for the sidebar filter
    if @board.aggregator?
      @all_tags = Task.joins(:board).where(boards: { user_id: current_user.id, is_aggregator: false }).where.not(tags: []).pluck(:tags).flatten.uniq.sort
    else
      @all_tags = @board.tasks.where.not(tags: []).pluck(:tags).flatten.uniq.sort
    end

    # Get all boards for the sidebar
    @boards = current_user.boards

    # Get API token for agent status display
    @api_token = current_user.api_token
  end

  def archived
    @board_page = true
    @boards = current_user.boards
    # Set empty columns for header partial (it expects @columns to exist)
    @columns = { inbox: [], in_progress: [] }
    tasks = @board.tasks.archived.reorder(archived_at: :desc, completed_at: :desc)
    @pagy, @tasks = pagy(tasks, items: 20)
  end

  def create
    @board = current_user.boards.new(board_params)

    if @board.save
      redirect_to board_path(@board), notice: "Board created."
    else
      redirect_to boards_path, alert: @board.errors.full_messages.join(", ")
    end
  end

  def update
    if @board.update(board_params)
      redirect_to board_path(@board), notice: "Board updated."
    else
      redirect_to board_path(@board), alert: @board.errors.full_messages.join(", ")
    end
  end

  def destroy
    # Don't allow deleting the last board
    if current_user.boards.count <= 1
      redirect_to board_path(@board), alert: "Cannot delete your only board."
      return
    end

    @board.destroy
    redirect_to boards_path, notice: "Board deleted."
  end

  def update_task_status
    # Update positions for all tasks in the column
    if params[:task_ids].present?
      params[:task_ids].each_with_index do |task_id, index|
        task = @board.tasks.find(task_id)
        task.update_columns(position: index + 1)
      end
    end

    # If a specific task changed status (moved between columns)
    if params[:task_id].present? && params[:status].present?
      @task = @board.tasks.find(params[:task_id])
      @task.activity_source = "web"
      @task.update!(status: params[:status])

      # Return rendered HTML so JS can replace the card (updates NEXT button, etc.)
      html = render_to_string(partial: "boards/task_card", locals: { task: @task })
      render json: { success: true, html: html, task_id: @task.id }
      return
    end

    head :ok
  end

  private

  def set_board
    @board = current_user.boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, :icon, :color)
  end
end
