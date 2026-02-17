# frozen_string_literal: true

module Api
  module V1
    class FactoryLoopAgentsController < BaseController
      before_action :set_loop

      def index
        loop_agents = @loop.factory_loop_agents.includes(:factory_agent).order(:id)

        render json: loop_agents.map { |la| serialize_loop_agent(la) }
      end

      def enable
        agent = FactoryAgent.find(params[:agent_id])
        loop_agent = FactoryLoopAgent.find_or_initialize_by(factory_loop: @loop, factory_agent: agent)
        loop_agent.enabled = true

        if loop_agent.save
          render json: serialize_loop_agent(loop_agent)
        else
          render json: { errors: loop_agent.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def disable
        loop_agent = @loop.factory_loop_agents.find_by!(factory_agent_id: params[:agent_id])
        loop_agent.enabled = false

        if loop_agent.save
          render json: serialize_loop_agent(loop_agent)
        else
          render json: { errors: loop_agent.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        loop_agent = @loop.factory_loop_agents.find_by!(factory_agent_id: params[:agent_id])

        if loop_agent.update(factory_loop_agent_params)
          render json: serialize_loop_agent(loop_agent)
        else
          render json: { errors: loop_agent.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_loop
        @loop = current_user.factory_loops.find(params[:loop_id])
      end

      def factory_loop_agent_params
        params.permit(:cooldown_hours_override, :confidence_threshold_override)
      end

      def serialize_loop_agent(loop_agent)
        agent = loop_agent.factory_agent
        last_run = FactoryAgentRun.where(factory_loop_id: @loop.id, factory_agent_id: agent.id)
                                  .order(created_at: :desc)
                                  .first

        cooldown_hours = loop_agent.cooldown_hours_override || agent.cooldown_hours || 0
        on_cooldown = last_run&.created_at.present? && cooldown_hours.positive? && last_run.created_at > cooldown_hours.hours.ago
        cooldown_until = on_cooldown ? (last_run.created_at + cooldown_hours.hours) : nil

        agent.as_json.merge(
          factory_loop_agent_id: loop_agent.id,
          enabled: loop_agent.enabled,
          cooldown_hours_override: loop_agent.cooldown_hours_override,
          confidence_threshold_override: loop_agent.confidence_threshold_override,
          last_run_at: last_run&.created_at,
          last_run_status: last_run&.status,
          on_cooldown: on_cooldown || false,
          cooldown_until: cooldown_until&.iso8601
        )
      end
    end
  end
end
