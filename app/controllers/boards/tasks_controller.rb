class Boards::TasksController < ApplicationController
  include MarkdownSanitizationHelper
  include OutputRenderable

  before_action :set_board
  before_action :set_task, only: [:show, :edit, :update, :destroy, :assign, :unassign, :move, :move_to_board, :followup_modal, :create_followup, :generate_followup, :enhance_followup, :handoff_modal, :handoff, :revalidate, :validation_output_modal, :validate_modal, :debate_modal, :review_output_modal, :run_validation, :run_debate, :view_file, :diff_file, :generate_validation_suggestion]

  def show
    @api_token = current_user.api_token
    @agent_personas = AgentPersona.for_user(current_user).active.order(:name)
    if turbo_frame_request?
      render layout: false
    else
      render # full layout for direct visits — shows task with back link
    end
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

    # Apply template if specified
    if params.dig(:task, :template_slug).present?
      template = TaskTemplate.find_for_user(params[:task][:template_slug], current_user)
      if template
        task_name = @task.name || @task.title || ""
        template_attrs = template.to_task_attributes(task_name)
        @task.assign_attributes(template_attrs.except(:name)) # Don't override name, it's already set
        @task.name = template_attrs[:name] if task_name.present? # Apply icon prefix
      end
    end

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

  def assign
    @task.activity_source = "web"
    @task.assign_to_agent!
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("task_#{@task.id}", partial: "boards/task_card", locals: { task: @task }),
          turbo_stream.replace("task_#{@task.id}_agent_assignment", partial: "boards/tasks/agent_assignment", locals: { task: @task, board: @board })
        ]
      end
      format.html { redirect_to board_path(@board), notice: "Task assigned to agent." }
    end
  end

  def unassign
    @task.activity_source = "web"
    @task.unassign_from_agent!
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("task_#{@task.id}", partial: "boards/task_card", locals: { task: @task }),
          turbo_stream.replace("task_#{@task.id}_agent_assignment", partial: "boards/tasks/agent_assignment", locals: { task: @task, board: @board })
        ]
      end
      format.html { redirect_to board_path(@board), notice: "Task unassigned from agent." }
    end
  end

  def move
    @old_status = @task.status
    @task.activity_source = "web"

    if @task.update(status: params[:status])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to board_path(@board), notice: "Task moved." }
        format.json { render json: { success: true, task_id: @task.id, status: @task.status } }
      end
    else
      respond_to do |format|
        format.turbo_stream { render plain: @task.errors.full_messages.join(", "), status: :unprocessable_entity }
        format.html { redirect_to board_path(@board), alert: @task.errors.full_messages.join(", ") }
        format.json { render json: { error: @task.errors.full_messages.join(", "), errors: @task.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def move_to_board
    target_board = current_user.boards.find(params[:target_board_id])

    @task.activity_source = "web"
    @task.update!(board_id: target_board.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("task_card_#{@task.id}"),
          turbo_stream.remove("task_#{@task.id}"),
          turbo_stream.append("flash-messages", partial: "shared/flash_toast", locals: {
            message: "Task moved to #{target_board.name}",
            type: "success"
          })
        ]
      end
      format.html { redirect_to board_path(@board), notice: "Task moved to #{target_board.name}" }
      format.json { render json: { success: true, task_id: @task.id, board: target_board.name } }
    end
  end

  def followup_modal
    # Don't generate suggestion here - let it load async via JS
    # @task.suggested_followup will be fetched by Stimulus controller
    render layout: false
  end

  def handoff_modal
    render layout: false
  end

  def handoff
    new_model = params[:model]
    unless Task::MODELS.include?(new_model)
      redirect_to board_path(@board), alert: "Invalid model selected"
      return
    end

    include_transcript = params[:include_transcript] == "1"

    @task.activity_source = "web"
    @task.activity_note = "Handoff from #{@task.model || 'default'} to #{new_model}"
    @task.handoff!(new_model: new_model, include_transcript: include_transcript)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to board_path(@board), notice: "Task handed off to #{new_model.upcase}" }
    end
  end

  def revalidate
    unless @task.validation_command.present?
      redirect_to board_path(@board), alert: "No validation command configured"
      return
    end

    @task.activity_source = "web"
    ValidationRunnerService.new(@task).call

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("task_#{@task.id}", partial: "boards/task_card", locals: { task: @task })
      end
      format.html { redirect_to board_path(@board), notice: "Validation #{@task.validation_status}" }
    end
  end

  def validation_output_modal
    render layout: false
  end

  def validate_modal
    render layout: false
  end

  def debate_modal
    render layout: false
  end

  def review_output_modal
    render layout: false
  end

  def run_validation
    command = params[:command].presence || @task.validation_command
    unless command.present?
      redirect_to board_path(@board), alert: "No validation command specified"
      return
    end

    @task.activity_source = "web"
    @task.start_review!(type: "command", config: { command: command })
    @task.update!(validation_command: command)

    # Run validation in background
    RunValidationJob.perform_later(@task.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("task_#{@task.id}", partial: "boards/task_card", locals: { task: @task.reload })
      end
      format.html { redirect_to board_path(@board), notice: "Validation started" }
    end
  end

  def view_file
    path = params[:path].to_s
    if path.blank?
      render plain: "Path parameter required", status: :bad_request
      return
    end

    # SECURITY FIX #495: Use resolve_safe_path for strict path validation
    # Build allowed directories list
    project_root = Rails.root.to_s
    storage_root = Rails.root.join("storage").to_s
    allowed_dirs = [project_root, storage_root]

    # Include board's project path if configured
    board_project_path = @task.board.try(:project_path)
    if board_project_path.present?
      allowed_dirs.unshift(File.expand_path(board_project_path))
    end

    # Use secure path resolution (rejects absolute paths, ~/, dotfiles, traversal)
    full_path = resolve_safe_path(path, allowed_dirs: allowed_dirs)

    # Security: path must resolve AND be in output_files list OR within allowed directories
    unless full_path
      render plain: "Access denied: invalid path", status: :forbidden
      return
    end

    unless File.exist?(full_path) && File.file?(full_path)
      @file_error = "File not found: #{path}"
      @file_path = path
      @frame_id = request.headers["Turbo-Frame"] || "file_viewer"
      render layout: false
      return
    end

    @file_path = path
    @file_extension = File.extname(full_path).delete(".")

    # Serve binary files (images, etc.) directly with proper content-type
    binary_types = {
      "png" => "image/png", "jpg" => "image/jpeg", "jpeg" => "image/jpeg",
      "gif" => "image/gif", "webp" => "image/webp", "svg" => "image/svg+xml",
      "pdf" => "application/pdf", "zip" => "application/zip"
    }
    if binary_types.key?(@file_extension.downcase)
      send_file full_path, type: binary_types[@file_extension.downcase], disposition: :inline
      return
    end

    @file_content = File.read(full_path, encoding: "UTF-8")

    # Detect which turbo frame is requesting (desktop vs mobile)
    @frame_id = request.headers["Turbo-Frame"] || "file_viewer"

    # Render markdown if applicable (using safe_markdown for XSS protection)
    if %w[md markdown].include?(@file_extension)
      @rendered_html = safe_markdown(@file_content)
    end

    render layout: false
  end

  def diff_file
    file_path = params[:path].to_s
    if file_path.blank?
      render plain: "Path parameter required", status: :bad_request
      return
    end

    task_diff = @task.task_diffs.find_by(file_path: file_path)
    unless task_diff
      render plain: "No diff available for this file", status: :not_found
      return
    end

    @task_diff = task_diff

    respond_to do |format|
      format.json do
        # Return raw unified diff for diff2html.js rendering
        unified = task_diff.unified_diff_string
        render json: {
          file_path: task_diff.file_path,
          diff_type: task_diff.diff_type,
          diff_content: unified,
          stats: task_diff.stats
        }
      end
      format.html do
        render partial: "boards/tasks/diff_viewer", locals: { task_diff: task_diff }, layout: false
      end
      format.any do
        render partial: "boards/tasks/diff_viewer", locals: { task_diff: task_diff }, layout: false
      end
    end
  end

  def run_debate
    # Debate review is not yet implemented — return early with notice
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "🚧 Debate review is not yet implemented. Coming soon!"
        render turbo_stream: turbo_stream.action(:redirect, board_path(@board))
      end
      format.html do
        redirect_to board_path(@board), alert: "🚧 Debate review is not yet implemented. Coming soon!"
      end
    end
    return

    style = params[:style] || "quick"
    focus = params[:focus]
    models = Array(params[:models]).reject(&:blank?)
    models = %w[gemini claude glm] if models.empty?

    @task.activity_source = "web"
    @task.start_review!(
      type: "debate",
      config: {
        style: style,
        focus: focus,
        models: models
      }
    )

    # Run debate in background
    RunDebateJob.perform_later(@task.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("task_#{@task.id}", partial: "boards/task_card", locals: { task: @task.reload })
      end
      format.html { redirect_to board_path(@board), notice: "Debate review started" }
    end
  end

  def generate_followup
    suggestion = @task.generate_followup_suggestion
    @task.update!(suggested_followup: suggestion) if suggestion.present?
    respond_to do |format|
      format.json { render json: { suggested_followup: suggestion } }
    end
  end

  def enhance_followup
    draft = params[:draft]
    @enhanced = AiSuggestionService.new(@task.user).enhance_description(@task, draft)
    respond_to do |format|
      format.turbo_stream
      format.json { render json: { enhanced: @enhanced || draft } }
    end
  end

  def generate_validation_suggestion
    suggestion = ValidationSuggestionService.new(current_user).generate_suggestion(@task)
    respond_to do |format|
      format.json { render json: { command: suggestion || "bin/rails test" } }
    end
  end

  # POST /boards/:board_id/tasks/bulk_update
  # Accepts: { task_ids: [...], action: "move_status|change_model|archive|delete", value: "done" }
  def bulk_update
    task_ids = params[:task_ids] || []
    bulk_action = params[:action_type] || params[:action]
    value = params[:value]

    # Handle JSON body parsing
    if request.content_type == "application/json"
      body = JSON.parse(request.body.read) rescue {}
      task_ids = body["task_ids"] || task_ids
      bulk_action = body["action"] || bulk_action
      value = body["value"] || value
    end

    tasks = @board.tasks.where(id: task_ids)

    if tasks.empty?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to board_path(@board), alert: "No tasks found." }
        format.json { render json: { error: "No tasks found" }, status: :unprocessable_entity }
      end
      return
    end

    streams = []
    affected_statuses = tasks.pluck(:status).uniq

    case bulk_action
    when "move_status"
      auto_sorted_statuses = %w[in_review done]
      tasks.each do |task|
        task.activity_source = "web"
        task.update!(status: value)
        streams << turbo_stream.remove("task_#{task.id}")

        unless auto_sorted_statuses.include?(value.to_s)
          streams << turbo_stream.prepend("column-#{value}", partial: "boards/task_card", locals: { task: task.reload })
        end
      end
      affected_statuses << value

    when "change_model"
      tasks.update_all(model: value)
      tasks.each do |task|
        streams << turbo_stream.replace("task_#{task.id}", partial: "boards/task_card", locals: { task: task.reload })
      end

    when "archive"
      tasks.each do |task|
        task.activity_source = "web"
        task.update!(status: :archived)
        streams << turbo_stream.remove("task_#{task.id}")
      end

    when "delete"
      tasks.each do |task|
        task.activity_source = "web"
        task.destroy
        streams << turbo_stream.remove("task_#{task.id}")
      end

    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to board_path(@board), alert: "Unknown action." }
        format.json { render json: { error: "Unknown action" }, status: :unprocessable_entity }
      end
      return
    end

    # Keep deterministic order in auto-sorted columns after bulk operations
    affected_statuses.uniq.each do |status|
      next unless %w[in_review done].include?(status.to_s)

      ordered_tasks = @board.tasks.not_archived.where(status: status)
        .includes(:board, :user, :agent_persona)
        .ordered_for_column(status)
      streams << turbo_stream.replace("column-#{status}", partial: "boards/column_tasks", locals: { status: status, tasks: ordered_tasks, board: @board })
    end

    # Update column counts
    affected_statuses.each do |status|
      count = @board.tasks.where(status: status).count
      streams << turbo_stream.update("column-#{status}-count", count.to_s)
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
      format.html { redirect_to board_path(@board), notice: "#{tasks.count} task(s) updated." }
      format.json { render json: { success: true, count: tasks.count } }
    end
  end

  def create_followup
    @task.activity_source = "web"
    followup_name = params[:followup_name].presence || "Follow up: #{@task.name}"
    followup_description = params[:followup_description]
    destination = params[:destination] || "inbox"
    selected_model = params[:model].presence  # nil means inherit
    continue_session = params[:continue_session] == "1"
    inherit_session_key = params[:inherit_session_key]

    @followup = @task.create_followup_task!(
      followup_name: followup_name,
      followup_description: followup_description
    )

    # Auto-complete parent task when follow-up is created
    @task.update!(status: "done", completed: true, completed_at: Time.current)

    # Override model if specified (otherwise inherits from parent)
    if selected_model.present?
      @followup.update!(model: selected_model)
    end

    # Handle session continuation - copy session key if user chose to continue
    if continue_session && inherit_session_key.present?
      @followup.update!(agent_session_key: inherit_session_key)
    end

    # Handle destination
    case destination
    when "up_next"
      @followup.update!(status: :up_next, assigned_to_agent: true, assigned_at: Time.current)
    when "in_progress"
      @followup.update!(status: :in_progress, assigned_to_agent: true, assigned_at: Time.current)
    when "nightly"
      @followup.update!(status: :up_next, nightly: true, assigned_to_agent: true, assigned_at: Time.current)
    end

    @destination_status = @followup.status

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to board_path(@board), notice: "Follow-up task created." }
    end
  end

  private

  def set_board
    @board = current_user.boards.find(params[:board_id])
  end

  def set_task
    @task = @board.tasks.includes(:activities, :parent_task, :followup_task, :task_runs).find(params[:id])
  end

  def task_params
    permitted = params.require(:task).permit(:name, :title, :description, :priority, :status, :blocked, :due_date, :completed, :model, :recurring, :recurrence_rule, :recurrence_time, :nightly, :nightly_delay_hours, :validation_command, :agent_persona_id, tags: [])
    # Allow 'title' as alias for 'name'
    permitted[:name] = permitted.delete(:title) if permitted[:title].present? && permitted[:name].blank?
    permitted
  end

  # Validation command execution delegated to ValidationRunnerService
end
