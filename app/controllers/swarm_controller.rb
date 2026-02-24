# frozen_string_literal: true

class SwarmController < ApplicationController
  before_action :set_idea, only: [:launch, :destroy, :update, :toggle_favorite]

  def index
    @ideas = current_user.swarm_ideas.enabled.includes(:board).order(favorite: :desc, category: :asc, title: :asc)
    @categories = SwarmIdea::CATEGORIES
    @models = SwarmIdea::MODELS
    @boards = current_user.boards.includes(:user).order(:name)
  end

  def launch
    board_id = params[:board_id].presence || @idea.board_id || current_user.boards.first&.id || 2
    model = params[:model].presence || @idea.suggested_model

    contract = SwarmTaskContract.build(
      idea: @idea,
      board_id: board_id,
      model: model,
      overrides: contract_overrides
    )

    validation = SwarmTaskContract.validate(contract)
    unless validation[:valid]
      return respond_to do |format|
        format.json { render json: { success: false, error: validation[:errors].join(", ") }, status: :unprocessable_entity }
        format.html { redirect_to swarm_path, alert: "Launch failed: #{validation[:errors].join(', ')}" }
      end
    end

    task = current_user.tasks.create!(
      name: @idea.title,
      description: @idea.description,
      board_id: board_id,
      status: :up_next,
      assigned_to_agent: true,
      model: model,
      pipeline_enabled: true,
      pipeline_type: @idea.pipeline_type.presence || "feature",
      execution_prompt: SwarmTaskContract.render_execution_prompt(contract),
      review_config: {
        "swarm_contract_version" => contract["version"],
        "swarm_contract" => contract
      },
      state_data: {
        "swarm_contract_status" => "created",
        "swarm_contract" => contract
      },
      tags: [@idea.category, "swarm"].compact
    )

    @idea.update!(times_launched: @idea.times_launched.to_i + 1, last_launched_at: Time.current)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          task_id: task.id,
          name: @idea.title,
          model: model,
          contract_id: contract["contract_id"],
          contract_version: contract["version"],
          times_launched: @idea.times_launched,
          launched_today: @idea.launched_today?
        }
      end
      format.html { redirect_to swarm_path, notice: "Task ##{task.id} created from '#{@idea.title}' (contract #{contract['contract_id']})" }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to swarm_path, alert: "Launch failed: #{e.message}" }
    end
  end

  def create
    @idea = current_user.swarm_ideas.build(idea_params)
    if @idea.save
      redirect_to swarm_path, notice: "Idea added"
    else
      redirect_to swarm_path, alert: @idea.errors.full_messages.join(", ")
    end
  end

  def update
    if @idea.update(idea_params)
      respond_to do |format|
        format.json { render json: { success: true } }
        format.html { redirect_to swarm_path, notice: "Idea updated" }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @idea.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to swarm_path, alert: @idea.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    @idea.destroy
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to swarm_path, notice: "Idea removed" }
    end
  end

  def toggle_favorite
    @idea.update!(favorite: !@idea.favorite)
    render json: { success: true, favorite: @idea.favorite }
  end

  private

  def set_idea
    @idea = current_user.swarm_ideas.find(params[:id])
  end

  def contract_overrides
    {
      orchestrator: params[:orchestrator],
      phase: params[:phase],
      acceptance_criteria: params[:acceptance_criteria],
      required_artifacts: params[:required_artifacts],
      skills: params[:skills]
    }
  end

  def idea_params
    params.require(:swarm_idea).permit(
      :title, :description, :category, :suggested_model, :source, :project,
      :estimated_minutes, :icon, :difficulty, :pipeline_type, :enabled, :favorite, :board_id
    )
  end
end
