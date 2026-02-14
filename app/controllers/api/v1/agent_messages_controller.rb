# frozen_string_literal: true

module Api
  module V1
    class AgentMessagesController < BaseController
      before_action :set_task

      # GET /api/v1/tasks/:task_id/agent_messages
      def index
        messages = @task.agent_messages
          .chronological
          .limit(params.fetch(:limit, 50).to_i.clamp(1, 200))

        messages = messages.where(direction: params[:direction]) if params[:direction].present?
        messages = messages.where(message_type: params[:type]) if params[:type].present?

        render json: messages.map { |m| serialize_message(m) }
      end

      # GET /api/v1/tasks/:task_id/agent_messages/thread
      # Returns a unified thread view: all messages for this task + any related
      # tasks in the same chain (parent → children → follow-ups).
      def thread
        task_ids = collect_chain_task_ids(@task)
        messages = AgentMessage
          .where(task_id: task_ids)
          .chronological
          .limit(params.fetch(:limit, 100).to_i.clamp(1, 500))

        render json: messages.map { |m| serialize_message(m) }
      end

      private

      def set_task
        @task = current_user.tasks.find_by(id: params[:task_id])
        render json: { error: "task not found" }, status: :not_found unless @task
      end

      # Walk up to parent + down to children/follow-ups to collect the chain
      def collect_chain_task_ids(task, visited = Set.new)
        return visited if visited.include?(task.id)
        visited << task.id

        # Walk up
        collect_chain_task_ids(task.parent_task, visited) if task.parent_task.present?

        # Walk down to children
        task.child_tasks.find_each { |child| collect_chain_task_ids(child, visited) }

        # Follow-up chain
        collect_chain_task_ids(task.followup_task, visited) if task.followup_task.present?

        # Source task (reverse follow-up)
        collect_chain_task_ids(task.source_task, visited) if task.source_task.present?

        visited
      end

      def serialize_message(msg)
        {
          id: msg.id,
          task_id: msg.task_id,
          source_task_id: msg.source_task_id,
          direction: msg.direction,
          message_type: msg.message_type,
          sender_model: msg.sender_model,
          sender_session_id: msg.sender_session_id,
          sender_name: msg.sender_name,
          content: msg.content,
          summary: msg.summary,
          metadata: msg.metadata,
          created_at: msg.created_at.iso8601
        }
      end
    end
  end
end
