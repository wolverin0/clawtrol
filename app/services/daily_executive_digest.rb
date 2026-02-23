class DailyExecutiveDigest
  def initialize(date = Date.current)
    @date = date
  end

  def generate
    {
      date: @date,
      done: completed_tasks,
      failed: failed_tasks,
      blocked: blocked_tasks,
      next_three: next_tasks
    }
  end

  private

  def completed_tasks
    Task.where('updated_at >= ?', @date.beginning_of_day).where(status: 'done').count
  end

  def failed_tasks
    # Assuming there's a failed status or we can check something else
    0
  end

  def blocked_tasks
    # Assuming there's a blocked status
    0
  end

  def next_tasks
    Task.where(status: ['up_next', 'inbox']).order(created_at: :asc).limit(3).pluck(:name)
  end
end
