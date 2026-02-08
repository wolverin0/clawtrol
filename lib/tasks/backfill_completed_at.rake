# frozen_string_literal: true

namespace :tasks do
  desc "Backfill completed_at for legacy done tasks where completed=true but completed_at is NULL (sets completed_at=updated_at)"
  task backfill_completed_at: :environment do
    scope = Task.where(completed: true, completed_at: nil)

    total = scope.count
    puts "Found #{total} tasks with completed=true and completed_at=NULL"

    updated = scope.update_all("completed_at = updated_at")
    puts "Updated #{updated} tasks"
  end
end
