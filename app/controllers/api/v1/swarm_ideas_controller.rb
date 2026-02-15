# frozen_string_literal: true

module Api
  module V1
    class SwarmIdeasController < BaseController
      before_action :set_idea, only: [:update, :destroy, :launch]

      def index
        ideas = current_user.swarm_ideas.enabled.order(category: :asc, title: :asc)
        ideas = ideas.by_category(params[:category]) if params[:category].present?
        render json: ideas
      end

      def create
        idea = current_user.swarm_ideas.build(idea_params)
        if idea.save
          render json: idea, status: :created
        else
          render json: { error: idea.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        if @idea.update(idea_params)
          render json: @idea
        else
          render json: { error: @idea.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @idea.destroy
        head :no_content
      end

      def launch
        model = params[:model].presence || @idea.suggested_model
        task = current_user.tasks.create!(
          name: @idea.title,
          description: @idea.description,
          board_id: params[:board_id] || current_user.boards.first&.id || 2,
          status: :up_next,
          assigned_to_agent: true,
          model: model,
          pipeline_enabled: true,
          tags: [@idea.category, "swarm"].compact
        )
        @idea.update!(times_launched: @idea.times_launched + 1, last_launched_at: Time.current)
        render json: { task_id: task.id, idea: @idea.title, model: model }
      end

      private

      def set_idea
        @idea = current_user.swarm_ideas.find(params[:id])
      end

      def idea_params
        params.require(:swarm_idea).permit(:title, :description, :category, :suggested_model, :source, :project, :estimated_minutes, :icon, :difficulty, :pipeline_type, :enabled)
      end
    end
  end
end
