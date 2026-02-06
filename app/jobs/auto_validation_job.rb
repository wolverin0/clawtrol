# Runs auto-validation after agent_complete
# - Generates rule-based validation command from output_files
# - If no command can be generated → leave in_review for human review
# - If command passes → auto-move to done
# - If command fails → move to in_progress, create follow-up task
class AutoValidationJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task
    return unless task.status == "in_review"

    # Generate validation command from output_files (rule-based only, no AI)
    command = ValidationSuggestionService.generate_rule_based(task)

    if command.blank?
      # No command could be generated — leave in_review for human
      Rails.logger.info("[AutoValidationJob] Task ##{task.id}: No validation command generated, staying in_review")
      return
    end

    # Set the validation command on the task
    task.update!(validation_command: command, validation_status: "pending")

    # Run the validation
    result = ValidationRunnerService.new(task, timeout: ValidationRunnerService::REVIEW_TIMEOUT).call

    user = task.board&.user

    if result.success?
      handle_validation_passed(task, user)
    else
      handle_validation_failed(task, user, result)
    end

    broadcast_task_update(task)
  rescue StandardError => e
    Rails.logger.error("[AutoValidationJob] Task ##{task_id} error: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    # On error, leave task in whatever state it's in — don't crash
  end

  private

  def handle_validation_passed(task, user)
    task.update!(
      status: :done,
      completed: true,
      completed_at: Time.current,
      validation_status: "passed"
    )

    # Create success notification
    if user
      Notification.create!(
        user: user,
        task: task,
        event_type: "validation_passed",
        message: "✅ #{task.name.truncate(60)} passed auto-validation"
      )
    end

    Rails.logger.info("[AutoValidationJob] Task ##{task.id}: Validation PASSED, moved to done")
  end

  def handle_validation_failed(task, user, result)
    # Move back to in_progress
    task.update!(
      status: :in_progress,
      validation_status: "failed"
    )

    # Create follow-up task with error context
    follow_up = Task.create!(
      name: "Fix: #{task.name.truncate(80)}",
      description: build_followup_description(task, result),
      board_id: task.board_id,
      user_id: task.user_id,
      parent_task_id: task.id,
      status: :in_progress,
      model: task.model,
      assigned_to_agent: true,
      assigned_at: Time.current,
      priority: :high
    )

    # Link parent to follow-up
    task.update!(followup_task_id: follow_up.id)

    # Create failure notification
    if user
      Notification.create!(
        user: user,
        task: task,
        event_type: "validation_failed",
        message: "❌ #{task.name.truncate(60)} failed validation"
      )
    end

    Rails.logger.info("[AutoValidationJob] Task ##{task.id}: Validation FAILED, created follow-up ##{follow_up.id}")

    # Broadcast the new follow-up task
    broadcast_task_update(follow_up)
  end

  def build_followup_description(task, result)
    output_preview = result.output.to_s.truncate(2000)
    
    <<~DESC
      Validation failed for parent task.

      **Command:** `#{task.validation_command}`
      **Exit code:** #{result.exit_code}

      ## Output
      ```
      #{output_preview}
      ```

      ---

      ## Original Task
      #{task.description.to_s.truncate(1000)}
    DESC
  end

  def broadcast_task_update(task)
    Turbo::StreamsChannel.broadcast_action_to(
      "board_#{task.board_id}",
      action: :replace,
      target: "task_#{task.id}",
      partial: "boards/task_card",
      locals: { task: task }
    )

    # Also notify WebSocket clients
    KanbanChannel.broadcast_refresh(task.board_id, task_id: task.id, action: "update")
  end
end
