# frozen_string_literal: true

class BoardsController < ApplicationController
  PER_COLUMN_ITEMS = Task::KANBAN_PER_COLUMN_ITEMS

  before_action :set_board, only: [:show, :update, :destroy, :update_task_status, :archived, :column]

  def index
    # Redirect to the first board
    @board = current_user.boards.order(position: :asc).first
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

    @tasks = scoped_tasks_for_board(@board)

    # Filter by tag if specified
    if params[:tag].present?
      @tasks = @tasks.where("? = ANY(tags)", params[:tag])
      @current_tag = params[:tag]
    end

    # Per-column pagination (initial render only shows first page)
    statuses = %i[inbox up_next in_progress in_review done]

    # Single grouped COUNT instead of 5 separate queries
    all_counts = @tasks.group(:status).count
    @column_counts = {}
    @columns = {}
    @columns_has_more = {}

    statuses.each do |status|
      scope = @tasks.where(status: status).ordered_for_column(status)
      first_page_plus_one = scope.limit(PER_COLUMN_ITEMS + 1).to_a

      @columns[status] = first_page_plus_one.first(PER_COLUMN_ITEMS)
      @columns_has_more[status] = first_page_plus_one.length > PER_COLUMN_ITEMS
      # group(:status).count returns string keys ("inbox", "up_next", etc.) in Rails 8
      @column_counts[status] = all_counts[status.to_s] || 0
    end

    # Get all unique tags for the sidebar filter
    if @board.aggregator?
      @all_tags = Task.joins(:board)
        .where(boards: { user_id: current_user.id, is_aggregator: false })
        .where.not(tags: nil)
        .where("array_length(tags, 1) > 0")
        .select("DISTINCT unnest(tags) as tag")
        .map(&:tag)
        .sort
    else
      @all_tags = @board.tasks
        .where.not(tags: nil)
        .where("array_length(tags, 1) > 0")
        .select("DISTINCT unnest(tags) as tag")
        .map(&:tag)
        .sort
    end

    # Get all boards for the sidebar
    @boards = current_user.boards.order(position: :asc)

    # Pre-compute task counts per board to avoid N+1 in board tabs partial.
    # Single query: GROUP BY board_id where status != done → Hash { board_id => count }
    @board_active_counts = current_user.tasks.where.not(status: :done)
                                       .group(:board_id).count
    @board_archived_count = @board.tasks.archived.count

    # Get API token for agent status display
    @api_token = current_user.api_token

    # Load agent personas for drag-assign sidebar
    @agent_personas = AgentPersona.for_user(current_user).active.order(:name)

    # Board status cluster (truthful running + queue signals)
    in_progress_ids = @tasks.where(status: :in_progress).select(:id)
    active_leases = RunnerLease.active.joins(:task).where(tasks: { id: in_progress_ids })
    @running_tasks_count = active_leases.count
    @running_oldest_hb_at = active_leases.minimum(:last_heartbeat_at)

    @queue_count = @tasks.where(status: :up_next, assigned_to_agent: true, blocked: false).count
  end

  def archived
    @board_page = true
    @boards = current_user.boards.order(position: :asc)
    @board_active_counts = current_user.tasks.where.not(status: :done)
                                       .group(:board_id).count
    @board_archived_count = @board.tasks.archived.count
    # Set empty columns for header partial (it expects @columns to exist)
    @columns = { inbox: [], in_progress: [] }
    tasks = if @board.aggregator?
              Task.joins(:board)
                  .where(boards: { user_id: current_user.id, is_aggregator: false })
                  .archived
                  .order(archived_at: :desc, completed_at: :desc)
    else
              @board.tasks.archived.order(archived_at: :desc, completed_at: :desc)
    end
    @pagy, @tasks = pagy(tasks, items: 20)

    # Handle AJAX requests for infinite scroll pagination
    if request.xhr?
      html = render_to_string(
        partial: "boards/archived_row",
        collection: @tasks,
        as: :task,
        locals: { board: @board }
      )
      response.set_header("X-Has-More", @pagy.next.present?.to_s)
      # html_safe is appropriate here: content is server-rendered from ERB partials
      # which auto-escape user input via ERBs default escaping
      render html: html.html_safe
    end
  end

  # Infinite-scroll pagination endpoint for a single kanban column.
  # Returns only the task cards HTML (no <ul>) so the client can append.
  def column
    status = params[:status].to_s

    unless Task.statuses.key?(status) && status != "archived"
      return head :bad_request
    end

    tasks = scoped_tasks_for_board(@board)

    if params[:tag].present?
      tasks = tasks.where("? = ANY(tags)", params[:tag])
    end

    scope = tasks.where(status: status).ordered_for_column(status)
    @pagy, @tasks = pagy(scope, limit: PER_COLUMN_ITEMS)

    html = render_to_string(
      partial: "boards/task_card",
      collection: @tasks,
      as: :task
    )

    response.set_header("X-Has-More", @pagy.next.present?.to_s)
    # html_safe is appropriate here: content is server-rendered from ERB partials
    # which auto-escape user input via ERBs default escaping
    render html: html.html_safe
  end

  # GET /boards/:id/dependency_graph
  def dependency_graph
    tasks = @board.tasks
      .where.not(status: "archived")
      .includes(:dependencies, :dependents)
      .select(:id, :name, :status, :blocked, :model, :board_id)

    deps = TaskDependency
      .joins(:task)
      .where(tasks: { board_id: @board.id })
      .pluck(:task_id, :depends_on_id)

    respond_to do |format|
      format.html
      format.json do
        nodes = tasks.map do |t|
          {
            id: t.id,
            name: t.name.to_s.truncate(40),
            status: t.status,
            blocked: t.blocked?,
            model: t.model,
            has_deps: t.dependencies.any?,
            has_dependents: t.dependents.any?
          }
        end

        links = deps.map { |tid, did| { source: did, target: tid } }

        render json: { nodes: nodes, links: links }
      end
    end
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
    # Update positions for all tasks in the column (atomic transaction)
    if params[:task_ids].present?
      task_ids = Array(params[:task_ids]).map(&:to_i)
      ActiveRecord::Base.transaction do
        # Build a single SQL CASE statement for all position updates
        # instead of N separate UPDATE queries
        if task_ids.any?
          when_clauses = task_ids.each_with_index.map { |id, idx|
            "WHEN #{id.to_i} THEN #{idx + 1}"
          }.join(" ")
          @board.tasks.where(id: task_ids).update_all(
            Arel.sql("position = CASE id #{when_clauses} END")
          )
        end
      end
    end

    # If a specific task changed status (moved between columns)
    if params[:task_id].present? && params[:status].present?
      unless Task.statuses.key?(params[:status])
        return render json: { error: "Invalid status: #{params[:status]}" }, status: :unprocessable_entity
      end

      @task = @board.tasks.find(params[:task_id])
      @task.activity_source = "web"

      if @task.update(status: params[:status])
        # Return rendered HTML so JS can replace the card (updates NEXT button, etc.)
        html = render_to_string(partial: "boards/task_card", locals: { task: @task })
        render json: { success: true, html: html, task_id: @task.id }
      else
        render json: {
          error: @task.errors.full_messages.join(", "),
          errors: @task.errors.full_messages
        }, status: :unprocessable_entity
      end
      return
    end

    head :ok
  end

  private

  def scoped_tasks_for_board(board)
    # For aggregator boards, show tasks from ALL non-aggregator boards
    if board.aggregator?
      @is_aggregator = true
      current_user.tasks
        .joins(:board)
        .where(boards: { is_aggregator: false })
        .not_archived
        .includes(:user, :board, :parent_task, :followup_task, :agent_persona, :runner_leases, :dependencies)
    else
      @is_aggregator = false
      board.tasks
        .not_archived
        .includes(:user, :parent_task, :followup_task, :agent_persona, :runner_leases, :dependencies)
    end
  end

  def set_board
    @board = current_user.boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, :icon, :color, :auto_claim_enabled, :auto_claim_prefix, auto_claim_tags: [])
  end
end
