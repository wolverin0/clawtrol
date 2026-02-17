# frozen_string_literal: true

class TaskDependency < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :task, inverse_of: :task_dependencies
  belongs_to :depends_on, class_name: "Task", inverse_of: :dependents

  validates :task_id, uniqueness: { scope: :depends_on_id, message: "already has this dependency" }
  validate :no_self_dependency
  validate :no_circular_dependency

  # Scopes for common queries
  scope :for_task, ->(task) { where(task_id: task.id) }
  scope :for_depends_on, ->(task) { where(depends_on_id: task.id) }
  scope :recent, -> { order(created_at: :desc).limit(100) }

  private

  def no_self_dependency
    if task_id == depends_on_id
      errors.add(:base, "A task cannot depend on itself")
    end
  end

  def no_circular_dependency
    return if depends_on_id.nil? || task_id.nil?

    # Check if adding this dependency would create a cycle
    # (i.e., if depends_on already depends on task, directly or indirectly)
    if would_create_cycle?
      errors.add(:base, "This dependency would create a circular dependency")
    end
  end

  def would_create_cycle?
    visited = Set.new
    queue = [depends_on_id]

    while queue.any?
      current_id = queue.shift
      return true if current_id == task_id
      next if visited.include?(current_id)

      visited << current_id

      # Find all tasks that current_id depends on
      TaskDependency.where(task_id: current_id).pluck(:depends_on_id).each do |dep_id|
        queue << dep_id unless visited.include?(dep_id)
      end
    end

    false
  end
end
