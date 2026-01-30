module Inbox
  class TasksController < ApplicationController
    before_action :set_inbox
    before_action :set_task, only: [ :edit, :update, :destroy, :toggle_completed, :cycle_priority, :send_to ]

    # GET /inbox/tasks/:id/edit
    def edit
    end

    # POST /inbox/tasks
    def create
      @task = @inbox.tasks.build(task_params)
      @task.user = current_user
      @task.task_list = @inbox.default_task_list
      @enter_pressed = params[:task][:enter_pressed] == "true"

      # Prepend: shift all existing incomplete tasks down and insert at position 1
      @task.task_list.tasks.incomplete.update_all("position = position + 1")
      @task.position = 1

      if @task.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to inbox_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("inbox-task-form", partial: "inbox/tasks/form", locals: { task: Task.new, error: @task.errors.full_messages.first }) }
          format.html { redirect_to inbox_path, alert: "Task could not be created." }
        end
      end
    end

    # PATCH/PUT /inbox/tasks/:id
    def update
      update_params = task_params.to_h

      # If uncompleting, handle position management
      if update_params.key?(:completed) && update_params[:completed] == false && @task.completed
        # Uncompleting - add to bottom of incomplete list
        max_position = @task.task_list.tasks.incomplete.maximum(:position) || 0
        update_params[:position] = max_position + 1
        update_params[:original_position] = nil
      end

      if @task.update(update_params)
        # Track if completed status changed (check after update)
        @completed_changed = @task.saved_change_to_completed?

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to inbox_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("task_#{@task.id}", partial: "inbox/tasks/task", locals: { task: @task }) }
          format.html { redirect_to inbox_path, alert: "Task could not be updated." }
        end
      end
    end

    # DELETE /inbox/tasks/:id
    def destroy
      @task_id = @task.id
      @task_list_id = @task.task_list_id
      @task.destroy!

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to inbox_path }
        format.json { head :ok }
      end
    end

    # POST /inbox/tasks/reorder
    def reorder
      task_ids = params[:task_ids]

      # Update positions for all tasks
      task_ids.each_with_index do |task_id, index|
        task = @inbox.tasks.find(task_id)
        task.update_columns(position: index + 1)
      end

      head :ok
    end

    # PATCH /inbox/tasks/:id/toggle_completed
    def toggle_completed
      if @task.completed
        # Uncompleting - add to bottom of incomplete list
        max_position = @task.task_list.tasks.incomplete.maximum(:position) || 0
        @task.update!(completed: false, position: max_position + 1, original_position: nil)
      else
        # Completing - original_position is saved in model callback
        @task.update!(completed: true)
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to inbox_path }
        format.json { head :ok }
      end
    end

    # PATCH /inbox/tasks/:id/cycle_priority
    def cycle_priority
      # Cycle: none (0) -> low (1) -> medium (2) -> high (3) -> none (0)
      next_priority = (@task.priority_before_type_cast + 1) % 4
      @task.update!(priority: next_priority)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to inbox_path }
      end
    end

    # PATCH /inbox/tasks/:id/send_to
    def send_to
      # Handle scheduling to Today (just sets due_date, doesn't move task)
      if params[:target_project_id] == "today"
        @task.update!(due_date: Date.current)

        return respond_to do |format|
          format.turbo_stream { render partial: "application/sidebar_badges" }
          format.html { redirect_to inbox_path, notice: "Added to today" }
        end
      end

      target_project = current_user.projects.visible.find(params[:target_project_id])

      # Move the task to the target project's task list
      target_task_list = target_project.default_task_list

      if params[:position] == "top"
        # Shift all existing incomplete tasks down and insert at top
        target_task_list.tasks.incomplete.update_all("position = position + 1")
        new_position = 1
      else
        new_position = (target_task_list.tasks.maximum(:position) || 0) + 1
      end

      @task.update!(project: target_project, task_list: target_task_list, position: new_position)

      respond_to do |format|
        notice_message = "Card sent to #{target_project.title}"
        format.turbo_stream do
          @task_id = @task.id
          @target_project = target_project
          render :send_to, locals: { notice_message: notice_message }
        end
        format.html { redirect_to inbox_path, notice: notice_message }
      end
    end

    private

    def set_inbox
      @inbox = current_user.inbox
    end

    def set_task
      @task = current_user.tasks.find(params[:id])
    end

    def task_params
      permitted = params.require(:task).permit(:name, :completed, :description, :priority, :due_date)
      if permitted.key?(:priority) && !permitted[:priority].nil?
        permitted[:priority] = permitted[:priority].to_i
      end
      permitted
    end
  end
end
