class TaskListsController < ApplicationController
  before_action :set_project
  before_action :set_task_list

  # PATCH/PUT /projects/:project_id/task_list
  def update
    if @task_list.update(task_list_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("task_list_#{@task_list.id}", partial: "task_lists/task_list", locals: { project: @project, task_list: @task_list }) }
        format.html { redirect_to @project, alert: "Task list could not be updated." }
      end
    end
  end

  # DELETE /projects/:project_id/task_list/delete_all_tasks
  def delete_all_tasks
    @task_ids = @task_list.tasks.pluck(:id)
    @task_list.tasks.destroy_all

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @project }
      format.json { head :ok }
    end
  end

  # DELETE /projects/:project_id/task_list/delete_completed_tasks
  def delete_completed_tasks
    @task_ids = @task_list.tasks.completed.pluck(:id)
    @task_list.tasks.completed.destroy_all

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @project }
      format.json { head :ok }
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_task_list
    @task_list = @project.default_task_list
  end

  def task_list_params
    params.require(:task_list).permit(:title)
  end
end
