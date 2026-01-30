class TodayController < ApplicationController
  def show
    @tasks = current_user.tasks
      .where(due_date: ..Date.current) # Today and overdue
      .where(completed: false)
      .includes(project: :image_attachment)
      .order(due_date: :asc, position: :asc)

    @completed_tasks = current_user.tasks
      .where(due_date: ..Date.current)
      .where(completed: true)
      .includes(project: :image_attachment)
      .order(completed_at: :desc)

    @inbox = current_user.inbox
    @other_projects = current_user.projects.visible.includes(:image_attachment)
  end
end
