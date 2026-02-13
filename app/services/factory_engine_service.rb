class FactoryEngineService
  TIMEOUT_MINUTES = 15
  MAX_CONSECUTIVE_FAILURES = 5

  def initialize(user = User.first)
    @user = user
  end

  def start_loop(loop)
    return unless loop.playing?
    FactoryRunnerJob.perform_later(loop.id)
  end

  def stop_loop(loop)
    # Discard any pending FactoryRunnerJob for this loop
    SolidQueue::Job.where(class_name: "FactoryRunnerJob")
      .where("arguments LIKE ?", "%#{loop.id}%")
      .where(finished_at: nil)
      .destroy_all
  end

  def record_cycle_result(cycle_log, status:, summary: nil, input_tokens: nil, output_tokens: nil, model_used: nil)
    loop = cycle_log.factory_loop

    cycle_log.update!(
      status: status,
      summary: summary,
      finished_at: Time.current,
      duration_ms: cycle_log.started_at ? ((Time.current - cycle_log.started_at) * 1000).to_i : nil,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      model_used: model_used
    )

    if status == "completed"
      loop.update!(
        consecutive_failures: 0,
        total_cycles: loop.total_cycles + 1,
        last_cycle_at: Time.current,
        last_error_at: nil,
        last_error_message: nil
      )
    else
      new_failures = loop.consecutive_failures + 1
      attrs = {
        consecutive_failures: new_failures,
        total_errors: loop.total_errors + 1,
        last_error_at: Time.current,
        last_error_message: summary || "Cycle #{status}"
      }
      if new_failures >= MAX_CONSECUTIVE_FAILURES
        attrs[:status] = "error_paused"
        # Stop the recursive job
        stop_loop(loop)
      end
      loop.update!(attrs)
    end
  end
end
