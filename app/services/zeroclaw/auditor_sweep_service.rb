# frozen_string_literal: true

module Zeroclaw
  class AuditorSweepService
    SweepResult = Struct.new(
      :scanned,
      :enqueued,
      :skipped_not_auditable,
      :skipped_recent,
      keyword_init: true
    )

    def initialize(trigger: "cron_sweep", limit: nil, min_interval_seconds: nil, lookback_hours: nil, force: false)
      @trigger = trigger.to_s
      @limit = limit.to_i
      @limit = AuditorConfig.sweep_limit if @limit <= 0

      @min_interval_seconds = min_interval_seconds.to_i
      @min_interval_seconds = AuditorConfig.min_interval_seconds if @min_interval_seconds <= 0

      @lookback_hours = lookback_hours.to_i
      @lookback_hours = AuditorConfig.sweep_lookback_hours if @lookback_hours <= 0

      @force = !!force
    end

    def call
      result = SweepResult.new(scanned: 0, enqueued: 0, skipped_not_auditable: 0, skipped_recent: 0)

      scope = Task.where(status: :in_review, assigned_to_agent: true).order(updated_at: :desc)
      scope = scope.where("updated_at >= ?", @lookback_hours.hours.ago) if @lookback_hours.positive?

      scope.limit(@limit * 4).each do |task|
        break if result.enqueued >= @limit

        result.scanned += 1

        unless AuditableTask.auditable?(task)
          result.skipped_not_auditable += 1
          next
        end

        if !@force && AuditableTask.recently_audited?(task, min_interval_seconds: @min_interval_seconds)
          result.skipped_recent += 1
          next
        end

        ZeroclawAuditorJob.perform_later(task.id, trigger: @trigger, force: @force)
        result.enqueued += 1
      end

      result.to_h.merge(
        trigger: @trigger,
        force: @force,
        limit: @limit,
        min_interval_seconds: @min_interval_seconds,
        lookback_hours: @lookback_hours
      )
    end
  end
end
