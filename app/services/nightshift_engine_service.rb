# frozen_string_literal: true

class NightshiftEngineService
  TIMEOUT_MINUTES = 30

  def run_tonight!
    return unless NightshiftSelection.for_tonight.armed.exists?

    NightshiftRunnerJob.perform_later
  end

  def complete_selection(selection, status:, result: nil)
    status = status.to_s

    # result column is text — serialize hashes/arrays as JSON for consistent storage
    serialized_result = case result
    when Hash, Array then result.to_json
    else result
    end

    attrs = {
      status: status,
      result: serialized_result
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
