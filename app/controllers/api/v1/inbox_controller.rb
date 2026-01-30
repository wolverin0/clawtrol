module Api
  module V1
    class InboxController < BaseController
      before_action :set_inbox

      # GET /api/v1/inbox/tasks
      def index
        @tasks = @inbox.tasks

        # Apply filters
        if params[:completed].present?
          completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
          @tasks = @tasks.where(completed: completed)
        end

        if params[:priority].present? && Task.priorities.key?(params[:priority])
          @tasks = @tasks.where(priority: params[:priority])
        end

        # Order: incomplete by position, completed by completed_at desc
        @tasks = @tasks.reorder(completed: :asc, position: :asc)

        render json: @tasks.map { |task| task_json(task) }
      end

      # POST /api/v1/inbox/tasks
      def create
        @task = @inbox.tasks.new(task_params)
        @task.user = current_user
        @task.task_list = @inbox.default_task_list
        @task.activity_source = "api"

        # Prepend: shift all existing incomplete tasks down and insert at position 1
        @task.task_list.tasks.incomplete.update_all("position = position + 1")
        @task.position = 1

        if @task.save
          render json: task_json(@task), status: :created
        else
          render json: { error: @task.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_inbox
        @inbox = current_user.inbox
      end

      def task_params
        params.require(:task).permit(:name, :description, :priority, :due_date)
      end

      def task_json(task)
        {
          id: task.id,
          name: task.name,
          description: task.description,
          priority: task.priority,
          completed: task.completed,
          completed_at: task.completed_at&.iso8601,
          due_date: task.due_date&.iso8601,
          position: task.position,
          project_id: task.project_id,
          inbox: true,
          created_at: task.created_at.iso8601,
          updated_at: task.updated_at.iso8601
        }
      end
    end
  end
end
