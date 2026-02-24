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
        board_id = params[:board_id].presence || current_user.boards.first&.id || 2

        contract = SwarmTaskContract.build(
          idea: @idea,
          board_id: board_id,
          model: model,
          overrides: contract_overrides
        )

        validation = SwarmTaskContract.validate(contract)
        unless validation[:valid]
          return render json: { error: validation[:errors].join(", ") }, status: :unprocessable_entity
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

        @idea.update!(times_launched: @idea.times_launched + 1, last_launched_at: Time.current)

        render json: {
          task_id: task.id,
          idea: @idea.title,
          model: model,
          contract_id: contract["contract_id"],
          contract_version: contract["version"]
        }
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
        params.require(:swarm_idea).permit(:title, :description, :category, :suggested_model, :source, :project, :estimated_minutes, :icon, :difficulty, :pipeline_type, :enabled)
      end
    end
  end
end
