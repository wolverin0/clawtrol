# frozen_string_literal: true

module Api
  module V1
    class FactoryAgentsController < BaseController
      before_action :set_agent, only: [ :show, :update ]

      def index
        agents = FactoryAgent.ordered.by_category(params[:category])

        if params[:builtin].present?
          agents = agents.where(builtin: ActiveModel::Type::Boolean.new.cast(params[:builtin]))
        end

        render json: agents
      end

      def show
        render json: @agent
      end

      def create
        agent = FactoryAgent.new(factory_agent_params.merge(builtin: false))
        if agent.save
          render json: agent, status: :created
        else
          render json: { errors: agent.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @agent.builtin?
          render json: { error: "Builtin agents cannot be modified" }, status: :forbidden
          return
        end

        if @agent.update(factory_agent_params)
          render json: @agent
        else
          render json: { errors: @agent.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_agent
        @agent = FactoryAgent.find(params[:id])
      end

      def factory_agent_params
        params.permit(
          :name, :slug, :category, :source, :system_prompt, :description,
          :tools_needed, :run_condition, :cooldown_hours,
          :default_confidence_threshold, :priority
        )
      end
    end
  end
end
