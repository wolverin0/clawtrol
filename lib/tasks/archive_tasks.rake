namespace :tasks do
  desc "One-time maintenance: archive tasks with id 1..250 (idempotent)"
  task archive_1_250: :environment do
    range = (1..250)
    now = Time.current

    archived = 0
    touched = 0

    Task.where(id: range).find_each do |task|
      touched += 1

      # NOTE: use update_columns to bypass validations (some historical tasks may
      # have invalid/unsafe validation_command values that would block updates).
      if task.archived?
        if task.archived_at.blank?
          task.update_columns(archived_at: now, updated_at: now)
          archived += 1
        end
        next
      end

      task.update_columns(
        status: Task.statuses[:archived],
        archived_at: (task.archived_at.presence || now),
        completed: false,
        completed_at: nil,
        updated_at: now
      )
      archived += 1
    end

    puts "Scanned #{touched} tasks in id range #{range.first}..#{range.last}"
    puts "Archived/updated #{archived} tasks"
  end
end
