module Api
  module V1
    class ProjectsController < BaseController
      before_action :set_project, only: :show

      # GET /api/v1/projects
      def index
        @projects = current_user.projects.visible

        render json: @projects.map { |project| project_json(project) }
      end

      # GET /api/v1/projects/:id
      def show
        render json: project_json(@project, include_counts: true)
      end

      # POST /api/v1/projects
      def create
        @project = current_user.projects.new(project_params)

        if @project.save
          render json: project_json(@project), status: :created
        else
          render json: { error: @project.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_project
        @project = current_user.projects.visible.find(params[:id])
      end

      def project_params
        params.require(:project).permit(:title, :description)
      end

      def project_json(project, include_counts: false)
        json = {
          id: project.id,
          title: project.title,
          description: project.description,
          position: project.position,
          created_at: project.created_at.iso8601,
          updated_at: project.updated_at.iso8601
        }

        if include_counts
          json[:task_count] = project.tasks.count
          json[:completed_task_count] = project.tasks.where(completed: true).count
          json[:incomplete_task_count] = project.tasks.where(completed: false).count
        end

        json
      end
    end
  end
end
