class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ edit update destroy ]

  # GET /projects or /projects.json
  def index
    @projects = current_user.projects.visible.includes(:image_attachment)
    # Pre-calculate task counts to avoid N+1 queries
    project_ids = @projects.pluck(:id)
    task_counts = Task.unscoped.where(project_id: project_ids).group(:project_id).count
    completed_task_counts = Task.unscoped.where(project_id: project_ids, completed: true).group(:project_id).count

    @projects.each do |project|
      project.instance_variable_set(:@task_count, task_counts[project.id] || 0)
      project.instance_variable_set(:@completed_task_count, completed_task_counts[project.id] || 0)
    end
  end

  # GET /projects/1 or /projects/1.json
  def show
    # Eager load task_list (tasks loaded via scopes in view for proper ordering)
    @project = current_user.projects.visible.includes(:image_attachment, :task_list).find(params.expect(:id))

    # Pre-calculate task counts for the project
    project_task_counts = Task.unscoped.where(project_id: @project.id).group(:project_id).count
    project_completed_counts = Task.unscoped.where(project_id: @project.id, completed: true).group(:project_id).count
    @project.instance_variable_set(:@task_count, project_task_counts[@project.id] || 0)
    @project.instance_variable_set(:@completed_task_count, project_completed_counts[@project.id] || 0)

    # Pre-calculate task counts for the task list
    task_list = @project.task_list
    if task_list
      task_count = Task.unscoped.where(task_list_id: task_list.id).count
      completed_count = Task.unscoped.where(task_list_id: task_list.id, completed: true).count
      task_list.instance_variable_set(:@task_count, task_count)
      task_list.instance_variable_set(:@completed_task_count, completed_count)
    end

    # Eager load other projects for send-to menus (visible projects only, excluding current)
    @other_projects = current_user.projects.visible.where.not(id: @project.id).includes(:image_attachment)
  end

  # GET /projects/new
  def new
    @project = current_user.projects.build
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects or /projects.json
  def create
    @project = current_user.projects.build(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    @project.image.purge if params[:project][:remove_image] == "1"

    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!

    respond_to do |format|
      format.html { redirect_to projects_path, notice: "Project was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /projects/reorder
  def reorder
    project_ids = params[:project_ids]

    Project.transaction do
      # First pass: set all positions to negative values to avoid unique constraint conflicts
      project_ids.each_with_index do |project_id, index|
        project = current_user.projects.unscoped.where(inbox: false).find(project_id)
        project.update_column(:position, -(index + 1))
      end

      # Second pass: set correct positive positions
      project_ids.each_with_index do |project_id, index|
        project = current_user.projects.unscoped.where(inbox: false).find(project_id)
        project.update_column(:position, index + 1)
      end
    end

    head :ok
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = current_user.projects.visible.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def project_params
      params.expect(project: [ :title, :description, :image ])
    end
end
