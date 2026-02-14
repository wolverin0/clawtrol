class SwarmController < ApplicationController
  def index
    @ideas = current_user.swarm_ideas.enabled.order(category: :asc, title: :asc)
    @categories = SwarmIdea::CATEGORIES
    @models = SwarmIdea::MODELS
  end

  def launch
    idea = current_user.swarm_ideas.find(params[:id])
    model = params[:model].presence || idea.suggested_model

    task = current_user.tasks.create!(
      name: idea.title,
      description: idea.description,
      board_id: params[:board_id] || current_user.boards.first&.id || 2,
      status: :up_next,
      assigned_to_agent: true,
      model: model,
      pipeline_enabled: true,
      tags: [idea.category, "swarm"].compact
    )

    idea.update!(times_launched: idea.times_launched + 1, last_launched_at: Time.current)

    redirect_to swarm_path, notice: "🚀 Task ##{task.id} created from '#{idea.title}' with model #{model}"
  end

  def create
    @idea = current_user.swarm_ideas.build(idea_params)
    if @idea.save
      redirect_to swarm_path, notice: "Idea added"
    else
      redirect_to swarm_path, alert: @idea.errors.full_messages.join(", ")
    end
  end

  def destroy
    current_user.swarm_ideas.find(params[:id]).destroy
    redirect_to swarm_path, notice: "Idea removed"
  end

  private

  def idea_params
    params.require(:swarm_idea).permit(:title, :description, :category, :suggested_model, :source, :project, :estimated_minutes, :icon, :difficulty, :pipeline_type, :enabled)
  end
end
