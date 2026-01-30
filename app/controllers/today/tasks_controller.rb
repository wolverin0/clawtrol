module Today
  class TasksController < ApplicationController
    before_action :set_inbox

    # POST /today/tasks
    def create
      @task = @inbox.tasks.build(task_params)
      @task.user = current_user
      @task.task_list = @inbox.default_task_list
      @task.due_date = Date.current
      @enter_pressed = params[:task][:enter_pressed] == "true"

      # Prepend: shift all existing incomplete tasks down and insert at position 1
      @task.task_list.tasks.incomplete.update_all("position = position + 1")
      @task.position = 1

      if @task.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to today_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("today-task-form", partial: "today/tasks/form", locals: { task: Task.new, error: @task.errors.full_messages.first }) }
          format.html { redirect_to today_path, alert: "Task could not be created." }
        end
      end
    end

    private

    def set_inbox
      @inbox = current_user.inbox
    end

    def task_params
      params.require(:task).permit(:name)
    end
  end
end
