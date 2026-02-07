class NightbeatController < ApplicationController
  def index
    @window_start, @window_end = overnight_window

    @nightly_tasks = current_user.tasks
      .nightly
      .done
      .where(completed_at: @window_start..@window_end)
      .includes(:board)
      .order(completed_at: :desc)

    @tasks_by_project = @nightly_tasks.group_by(&:board)
    @findings_summary = build_findings_summary(@nightly_tasks)
  end

  private

  def overnight_window
    now = Time.zone.now
    start = (now.to_date - 1.day).in_time_zone.change(hour: 20)
    finish = now.to_date.in_time_zone.change(hour: 10)
    finish = now if now < finish

    [start, finish]
  end

  def build_findings_summary(tasks)
    tasks.each_with_object({}) do |task, summary|
      snippet = task.description.to_s
      snippet = snippet.split("## Agent Output").last.to_s.strip if snippet.include?("## Agent Output")
      snippet = snippet.gsub(/\s+/, " ").truncate(180)
      snippet = "Completed overnight" if snippet.blank?

      summary[task.id] = snippet
    end
  end
end
