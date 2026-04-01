# frozen_string_literal: true

module Api
  module V1
    class OpenclawFlowsController < BaseController
      before_action :set_flow, only: [:show]

      # GET /api/v1/openclaw_flows
      def index
        flows = current_user.openclaw_flows.recent
        flows = flows.where(status: params[:status]) if params[:status].present?
        render json: flows.limit(params[:limit]&.to_i || 50)
      end

      # GET /api/v1/openclaw_flows/:id
      def show
        render json: @flow.as_json(include: { tasks: { only: [:id, :name, :status] } })
      end

      # POST /api/v1/openclaw_flows/sync
      def sync
        flow = current_user.openclaw_flows.find_or_initialize_by(flow_id: params[:flow_id])
        flow.assign_attributes(sync_params)
        flow.last_sync_at = Time.current

        if flow.task_id.nil? && flow.session_key.present?
          matching = current_user.tasks.where(agent_session_key: flow.session_key).first
          flow.task = matching if matching
        end

        if flow.save
          if flow.task.present? && flow.task.openclaw_flow_id != flow.id
            flow.task.update_column(:openclaw_flow_id, flow.id)
          end
          render json: { success: true, flow: flow }
        else
          render json: { error: flow.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/openclaw_flows/active
      def active
        flows = current_user.openclaw_flows.active.recent.limit(20)
        render json: flows.map { |f|
          f.as_json.merge(
            task_name: f.task&.name,
            task_status: f.task&.status,
            task_id: f.task_id,
            duration_minutes: f.started_at ? ((Time.current - f.started_at) / 60).round : nil
          )
        }
      end

      private

      def set_flow
        @flow = current_user.openclaw_flows.find(params[:id])
      end

      def sync_params
        params.permit(:flow_type, :status, :model, :agent_id, :session_key,
                      :parent_session_key, :child_count, :completed_count,
                      :blocked_reason, :started_at, :completed_at, metadata: {})
      end
    end
  end
end
