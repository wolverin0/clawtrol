class NightshiftEngineService
  TIMEOUT_MINUTES = 30

  def run_tonight!
    return unless NightshiftSelection.for_tonight.armed.exists?

    NightshiftRunnerJob.perform_later
  end

  def complete_selection(selection, status:, result: nil)
    status = status.to_s
    attrs = {
      status: status,
      result: result
    }

    attrs[:launched_at] = Time.current if status == "running" && selection.launched_at.nil?
    attrs[:completed_at] = Time.current if %w[completed failed].include?(status)

    selection.update!(attrs)

    if %w[completed failed].include?(status)
      selection.nightshift_mission.update!(last_run_at: Time.current)
    end

    selection
  end
end
