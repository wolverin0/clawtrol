# frozen_string_literal: true

class CronjobsController < ApplicationController
  include OpenclawCliRunnable

  def index
    respond_to do |format|
      format.html
      format.json do
        data = fetch_cronjobs

        if data[:status] == "offline"
          render json: data, status: :service_unavailable
        else
          render json: data
        end
      rescue StandardError => e
        Rails.logger.error("CRONJOBS ERROR: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { status: "offline", error: e.message }, status: :service_unavailable
      end
    end
  end

  def create
    args = build_cron_add_args
    result = run_openclaw_cli("cron", "add", *args)

    if result[:exitstatus] != 0
      error_msg = result[:stderr].to_s.strip.presence || result[:stdout].to_s.strip.presence || "Failed to create cron job"
      return respond_to do |format|
        format.json { render json: { ok: false, error: error_msg }, status: :unprocessable_entity }
        format.html { redirect_to cronjobs_path, alert: error_msg }
      end
    end

    invalidate_cron_cache
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_to cronjobs_path, notice: "Cron job created." }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to cronjobs_path, alert: e.message }
    end
  end

  def update
    id = params[:id].to_s
    return head(:bad_request) unless id.match?(/\A[\w.-]+\z/)

    args = build_cron_edit_args
    result = run_openclaw_cli("cron", "edit", id, *args)

    if result[:exitstatus] != 0
      error_msg = result[:stderr].to_s.strip.presence || result[:stdout].to_s.strip.presence || "Failed to update cron job"
      return respond_to do |format|
        format.json { render json: { ok: false, error: error_msg }, status: :unprocessable_entity }
        format.html { redirect_to cronjobs_path, alert: error_msg }
      end
    end

    invalidate_cron_cache
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_to cronjobs_path, notice: "Cron job updated." }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to cronjobs_path, alert: e.message }
    end
  end

  def destroy
    id = params[:id].to_s
    return head(:bad_request) unless id.match?(/\A[\w.-]+\z/)

    result = run_openclaw_cli("cron", "remove", id)

    if result[:exitstatus] != 0
      error_msg = result[:stderr].to_s.strip.presence || "Failed to delete cron job"
      return respond_to do |format|
        format.json { render json: { ok: false, error: error_msg }, status: :unprocessable_entity }
        format.html { redirect_to cronjobs_path, alert: error_msg }
      end
    end

    invalidate_cron_cache
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_to cronjobs_path, notice: "Cron job deleted." }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to cronjobs_path, alert: e.message }
    end
  end

  def toggle
    id = params[:id].to_s
    return head(:bad_request) unless id.match?(/\A[\w.-]+\z/)
    desired = params.key?(:enabled) ? ActiveModel::Type::Boolean.new.cast(params[:enabled]) : nil

    if desired.nil?
      return render json: { ok: false, error: "missing enabled param" }, status: :unprocessable_entity
    end

    cmd = desired ? %w[openclaw cron enable] : %w[openclaw cron disable]

    result = run_openclaw_cli(*cmd[1..], id)

    if result[:exitstatus] != 0
      msg = "openclaw cron #{desired ? "enable" : "disable"} failed"
      msg += " (exit=#{result[:exitstatus]})" if result[:exitstatus]
      msg += ": #{result[:stderr].strip}" if result[:stderr].present?
      return render json: { ok: false, error: msg, stdout: result[:stdout].to_s }, status: :unprocessable_entity
    end

    Rails.cache.delete("cronjobs/index/v1/user=#{current_user.id}")
    render json: { ok: true, id: id, enabled: desired }
  rescue Errno::ENOENT
    render json: { ok: false, error: "openclaw CLI not found" }, status: :service_unavailable
  rescue Timeout::Error
    render json: { ok: false, error: "openclaw cron command timed out" }, status: :service_unavailable
  end

  def run
    id = params[:id].to_s
    return head(:bad_request) unless id.match?(/\A[\w.-]+\z/)

    result = run_openclaw_cli("cron", "run", id)

    if result[:exitstatus] != 0
      msg = "openclaw cron run failed"
      msg += " (exit=#{result[:exitstatus]})" if result[:exitstatus]
      msg += ": #{result[:stderr].strip}" if result[:stderr].present?
      return render json: { ok: false, error: msg, stdout: result[:stdout].to_s }, status: :unprocessable_entity
    end

    render json: { ok: true, id: id }
  rescue Errno::ENOENT
    render json: { ok: false, error: "openclaw CLI not found" }, status: :service_unavailable
  rescue Timeout::Error
    render json: { ok: false, error: "openclaw cron command timed out" }, status: :service_unavailable
  end

  private

  def build_cron_add_args
    job = (params[:job] || params).to_unsafe_h.deep_symbolize_keys
    schedule = job[:schedule] || {}
    payload = job[:payload] || {}
    session_target = job[:sessionTarget] || job[:session_target] || "isolated"
    delivery = job[:delivery] || {}

    args = []
    args.push("--name", job[:name]) if job[:name].present?

    # Schedule
    case schedule[:kind]
    when "cron"
      args.push("--cron", schedule[:expr].to_s)
      args.push("--tz", schedule[:tz].to_s) if schedule[:tz].present?
    when "every"
      ms = schedule[:everyMs].to_i
      if ms >= 3_600_000
        args.push("--every", "#{ms / 3_600_000}h")
      else
        args.push("--every", "#{ms / 60_000}m")
      end
    when "at"
      args.push("--at", schedule[:at].to_s)
    end

    # Session target
    args.push("--session", session_target)

    # Payload
    if session_target == "isolated"
      args.push("--message", payload[:message].to_s) if payload[:message].present?
      args.push("--model", payload[:model].to_s) if payload[:model].present?
    else
      args.push("--system-event", payload[:text].to_s) if payload[:text].present?
    end

    # Delivery
    if delivery[:mode] == "announce"
      args.push("--announce")
      args.push("--channel", delivery[:channel].to_s) if delivery[:channel].present?
      args.push("--to", delivery[:to].to_s) if delivery[:to].present?
    end

    args
  end

  def build_cron_edit_args
    # Same structure as add but only includes fields that were sent
    build_cron_add_args
  end

  def build_job_from_params
    job = params[:job] || params
    {
      name: job[:name].presence,
      schedule: job[:schedule]&.to_unsafe_h || {},
      payload: job[:payload]&.to_unsafe_h || {},
      sessionTarget: job[:sessionTarget] || job[:session_target] || "isolated",
      delivery: job[:delivery]&.to_unsafe_h,
      enabled: true
    }.compact
  end

  def build_patch_from_params
    job = params[:job] || params
    patch = {}
    patch[:name] = job[:name] if job.key?(:name)
    patch[:schedule] = job[:schedule]&.to_unsafe_h if job.key?(:schedule)
    patch[:payload] = job[:payload]&.to_unsafe_h if job.key?(:payload)
    patch[:sessionTarget] = job[:sessionTarget] || job[:session_target] if job.key?(:sessionTarget) || job.key?(:session_target)
    patch[:delivery] = job[:delivery]&.to_unsafe_h if job.key?(:delivery)
    patch[:enabled] = job[:enabled] if job.key?(:enabled)
    patch.compact
  end

  def fetch_cronjobs
    result = run_openclaw_cron_list

    stdout = result.fetch(:stdout)
    stderr = result.fetch(:stderr)
    exitstatus = result[:exitstatus]

    unless exitstatus == 0
      msg = "openclaw cron list failed"
      msg += " (exit=#{exitstatus})" if exitstatus
      msg += ": #{stderr.strip}" if stderr.present?
      return { status: "offline", error: msg }
    end

    raw = JSON.parse(stdout)
    jobs = Array(raw["jobs"]).map { |j| normalize_job(j) }

    {
      status: "online",
      source: "cli",
      count: jobs.length,
      generatedAt: Time.current.iso8601(3),
      jobs: jobs
    }
  rescue Errno::ENOENT
    { status: "offline", error: "openclaw CLI not found" }
  rescue Timeout::Error
    { status: "offline", error: "openclaw cron list timed out" }
  rescue JSON::ParserError
    { status: "offline", error: "invalid JSON from openclaw cron list" }
  end

  def run_openclaw_cron_list
    run_openclaw_cli("cron", "list", "--json", "--all")
  end

  def normalize_job(job)
    schedule = job["schedule"] || {}
    state = job["state"] || {}

    next_run = ms_to_time(state["nextRunAtMs"])
    last_run = ms_to_time(state["lastRunAtMs"])

    {
      id: job["id"],
      name: job["name"].presence || job["id"],
      agentId: job["agentId"],
      enabled: !!job["enabled"],
      schedule: schedule,
      scheduleText: helpers.humanize_openclaw_schedule(schedule),
      nextRunAt: next_run&.iso8601(3),
      lastRunAt: last_run&.iso8601(3),
      lastStatus: state["lastStatus"],
      lastDurationMs: state["lastDurationMs"],
      consecutiveErrors: state["consecutiveErrors"],
      sessionTarget: job["sessionTarget"],
      wakeMode: job["wakeMode"],
      delivery: job["delivery"],
      payload: job["payload"]
    }
  rescue StandardError
    {
      id: job["id"],
      name: job["name"].presence || job["id"],
      enabled: !!job["enabled"],
      scheduleText: "(unparseable)",
      raw: job
    }
  end

  def invalidate_cron_cache
    # no-op: caching removed to avoid stale/error data
  end
end
