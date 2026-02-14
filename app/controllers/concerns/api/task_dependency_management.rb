# frozen_string_literal: true

module Api
  module TaskDependencyManagement
    extend ActiveSupport::Concern

    # GET /api/v1/tasks/:id/dependencies
    # Returns the task's dependencies and dependents
    def dependencies
      render json: {
        dependencies: @task.dependencies.map { |t| dependency_json(t) },
        dependents: @task.dependents.map { |t| dependency_json(t) },
        blocked: @task.blocked?,
        blocking_tasks: @task.blocking_tasks.map { |t| dependency_json(t) }
      }
    end

    # POST /api/v1/tasks/:id/add_dependency
    # Add a dependency to this task (this task depends on another)
    def add_dependency
      depends_on_id = params[:depends_on_id]

      unless depends_on_id.present?
        return render json: { error: "depends_on_id parameter required" }, status: :bad_request
      end

      depends_on = current_user.tasks.find_by(id: depends_on_id)

      unless depends_on
        return render json: { error: "Task #{depends_on_id} not found" }, status: :not_found
      end

      begin
        dependency = @task.task_dependencies.create!(depends_on: depends_on)
        set_task_activity_info(@task)
        @task.activity_note = "Added dependency on ##{depends_on.id}: #{depends_on.name.truncate(30)}"
        @task.touch  # Trigger activity recording

        render json: {
          success: true,
          dependency: {
            id: dependency.id,
            task_id: @task.id,
            depends_on_id: depends_on.id,
            depends_on: dependency_json(depends_on)
          },
          blocked: @task.reload.blocked?
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v1/tasks/:id/remove_dependency
    # Remove a dependency from this task
    def remove_dependency
      depends_on_id = params[:depends_on_id]

      unless depends_on_id.present?
        return render json: { error: "depends_on_id parameter required" }, status: :bad_request
      end

      dependency = @task.task_dependencies.find_by(depends_on_id: depends_on_id)

      unless dependency
        return render json: { error: "Dependency not found" }, status: :not_found
      end

      depends_on = dependency.depends_on
      dependency.destroy!

      set_task_activity_info(@task)
      @task.activity_note = "Removed dependency on ##{depends_on.id}: #{depends_on.name.truncate(30)}"
      @task.touch  # Trigger activity recording

      render json: {
        success: true,
        blocked: @task.reload.blocked?
      }
    end

    private

    def dependency_json(task)
      TaskSerializer.dependency_json(task)
    end
  end
end
