module Api
  module V1
    class WorkflowsController < BaseController
      def run
        workflow = Workflow.find(params[:id])

        render json: {
          error: "not_implemented",
          workflow: {
            id: workflow.id,
            title: workflow.title,
            active: workflow.active,
            definition: workflow.definition
          }
        }, status: :not_implemented
      end
    end
  end
end
