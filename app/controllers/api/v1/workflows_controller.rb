# frozen_string_literal: true

module Api
  module V1
    class WorkflowsController < BaseController
      def run
        workflow = Workflow.for_user(current_user).find(params[:id])

        engine = WorkflowExecutionEngine.new(workflow, user: current_user)
        result = engine.run

        if result.ok?
          render json: serialize_result(workflow, result), status: :ok
        else
          render json: serialize_result(workflow, result), status: :unprocessable_entity
        end
      end

      private

      def serialize_result(workflow, result)
        {
          runId: result.run_id,
          workflow: {
            id: workflow.id,
            title: workflow.title,
            active: workflow.active
          },
          status: result.status,
          errors: result.errors,
          nodes: result.nodes.map { |n|
            {
              id: n.id,
              type: n.type,
              label: n.label,
              status: n.status,
              startedAt: n.started_at&.iso8601,
              finishedAt: n.finished_at&.iso8601,
              logs: n.logs,
              output: n.output,
              session: n.session
            }
          }
        }
      end
    end
  end
end
