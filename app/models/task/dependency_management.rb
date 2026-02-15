# frozen_string_literal: true

module Task::DependencyManagement
  extend ActiveSupport::Concern

  # Blocking/dependency state methods
  def blocked?
    if dependencies.loaded?
      dependencies.any? { |d| !d.status.in?(%w[done archived]) }
    else
      dependencies.where.not(status: [:done, :archived]).exists?
    end
  end

  def blocking_tasks
    if dependencies.loaded?
      dependencies.select { |d| !d.status.in?(%w[done archived]) }
    else
      dependencies.where.not(status: [:done, :archived])
    end
  end

  def add_dependency!(other_task)
    task_dependencies.create!(depends_on: other_task)
  end

  def remove_dependency!(other_task)
    task_dependencies.find_by(depends_on: other_task)&.destroy!
  end
end
