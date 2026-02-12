class WorkflowsController < ApplicationController
  before_action :require_authentication
  before_action :set_workflow, only: [:edit, :update, :editor]

  def index
    @workflows = Workflow.order(created_at: :desc)
  end

  def new
    @workflow = Workflow.new
  end

  def create
    @workflow = Workflow.new(workflow_params)

    if @workflow.save
      redirect_to editor_workflow_path(@workflow), notice: "Workflow created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workflow.update(workflow_params)
      redirect_to editor_workflow_path(@workflow), notice: "Workflow saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Editor can be accessed as:
  # - GET /workflows/editor (new workflow in editor)
  # - GET /workflows/:id/editor (existing workflow)
  def editor
    @workflow ||= Workflow.new(title: "Untitled")
    render :editor
  end

  private

  def set_workflow
    @workflow = Workflow.find(params[:id]) if params[:id].present?
  end

  def workflow_params
    permitted = params.require(:workflow).permit(:title, :active, :definition)

    if permitted[:definition].is_a?(String)
      begin
        permitted[:definition] = JSON.parse(permitted[:definition].presence || "{}")
      rescue JSON::ParserError
        permitted[:definition] = {}
      end
    end

    permitted
  end
end
