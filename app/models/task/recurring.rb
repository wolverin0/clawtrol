# frozen_string_literal: true

module Task::Recurring
  extend ActiveSupport::Concern

  included do
    before_save :set_initial_recurrence, if: :will_save_change_to_recurring?
    after_update :handle_recurring_completion, if: :saved_change_to_status?
  end

  # Recurring task methods
  def recurring_template?
    recurring? && parent_task_id.nil?
  end

  def recurring_instance?
    parent_task_id.present? && parent_task&.recurring?
  end

  def schedule_next_recurrence!
    return unless recurring_template?

    next_time = calculate_next_recurrence
    update!(next_recurrence_at: next_time) if next_time
  end

  def create_recurring_instance!
    return nil unless recurring_template?

    instance = dup
    instance.parent_task_id = id
    instance.recurring = false
    instance.recurrence_rule = nil
    instance.recurrence_time = nil
    instance.next_recurrence_at = nil
    instance.status = :inbox
    instance.completed = false
    instance.completed_at = nil
    instance.assigned_to_agent = false
    instance.assigned_at = nil
    instance.agent_claimed_at = nil
    instance.position = nil
    instance.save!
    instance
  end

  def calculate_next_recurrence
    return nil unless recurrence_rule.present?

    base_time = recurrence_time || Time.current.beginning_of_day
    today = Date.current

    case recurrence_rule
    when "daily"
      next_date = today + 1.day
    when "weekly"
      next_date = today + 1.week
    when "monthly"
      next_date = today + 1.month
    else
      return nil
    end

    Time.zone.local(next_date.year, next_date.month, next_date.day, base_time.hour, base_time.min)
  end

  private

  def set_initial_recurrence
    if recurring? && parent_task_id.nil?
      self.next_recurrence_at = calculate_next_recurrence
    elsif !recurring?
      self.next_recurrence_at = nil
    end
  end

  def handle_recurring_completion
    return unless status == "done" && recurring_instance? && parent_task.present?

    # When a recurring instance is completed, schedule the next one on the template
    parent_task.schedule_next_recurrence!
  end
end
