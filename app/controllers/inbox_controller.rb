class InboxController < ApplicationController
  def show
    @inbox = current_user.inbox
    @task_list = @inbox.task_list

    # Pre-calculate task counts for the inbox
    if @task_list
      task_count = Task.unscoped.where(task_list_id: @task_list.id).count
      completed_count = Task.unscoped.where(task_list_id: @task_list.id, completed: true).count
      @task_list.instance_variable_set(:@task_count, task_count)
      @task_list.instance_variable_set(:@completed_task_count, completed_count)
    end

    # Eager load other projects for send-to menus (visible projects only)
    @other_projects = current_user.projects.visible.includes(:image_attachment)
  end
end
