require "open3"
require "timeout"

class CronjobsController < ApplicationController
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
    client = OpenclawGatewayClient.new(current_user)
    result = client.cron_create(cron_params)

    respond_to do |format|
      format.json { render json: { ok: true, cron: result } }
      format.html { redirect_to cronjobs_path, notice: "Cron job created." }
    end
  rescue => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to cronjobs_path, alert: e.message }
    end
  end

  def destroy
    id = params[:id].to_s
    return head(:bad_request) unless id.match?(/\A[\w.-]+\z/)

    client = OpenclawGatewayClient.new(current_user)
    client.cron_delete(id)

    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_to cronjobs_path, notice: "Cron job deleted." }
    end
  rescue => e
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

    stdout, stderr, status = Timeout.timeout(openclaw_timeout_seconds) do
      Open3.capture3(*cmd, id)
    end

    if status&.exitstatus != 0
      msg = "openclaw cron #{desired ? "enable" : "disable"} failed"
      msg += " (exit=#{status&.exitstatus})" if status&.exitstatus
      msg += ": #{stderr.strip}" if stderr.present?
      return render json: { ok: false, error: msg, stdout: stdout.to_s }, status: :unprocessable_entity
    end

    render json: { ok: true, id: id, enabled: desired }
  rescue Errno::ENOENT
    render json: { ok: false, error: "openclaw CLI not found" }, status: :service_unavailable
  rescue Timeout::Error
    render json: { ok: false, error: "openclaw cron command timed out" }, status: :service_unavailable
  end

  def run
    id = params[:id].to_s
    return head(:bad_request) unless id.match?(/\A[\w.-]+\z/)

    stdout, stderr, status = Timeout.timeout(openclaw_timeout_seconds) do
      Open3.capture3("openclaw", "cron", "run", id)
    end

    if status&.exitstatus != 0
      msg = "openclaw cron run failed"
      msg += " (exit=#{status&.exitstatus})" if status&.exitstatus
      msg += ": #{stderr.strip}" if stderr.present?
      return render json: { ok: false, error: msg, stdout: stdout.to_s }, status: :unprocessable_entity
    end

    render json: { ok: true, id: id }
  rescue Errno::ENOENT
    render json: { ok: false, error: "openclaw CLI not found" }, status: :service_unavailable
  rescue Timeout::Error
    render json: { ok: false, error: "openclaw cron command timed out" }, status: :service_unavailable
  end

  private

  def cron_params
    params.permit(:name, :agent_id, :schedule, :enabled, :session_target, :wake_mode, :prompt)
  end

  def fetch_cronjobs
    result = Rails.cache.fetch("cronjobs/index/v1", expires_in: cache_ttl) do
      run_openclaw_cron_list
    end

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
    stdout, stderr, status = Timeout.timeout(openclaw_timeout_seconds) do
      Open3.capture3("openclaw", "cron", "list", "--json")
    end

    {
      stdout: stdout,
      stderr: stderr,
      exitstatus: status&.exitstatus
    }
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
      delivery: job["delivery"]
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

  def ms_to_time(ms)
    return nil if ms.blank?
    Time.at(ms.to_f / 1000.0)
  rescue StandardError
    nil
  end

  def openclaw_timeout_seconds
    Integer(ENV.fetch("OPENCLAW_COMMAND_TIMEOUT_SECONDS", "20"))
  rescue ArgumentError
    20
  end

  def cache_ttl
    Integer(ENV.fetch("CRONJOBS_CACHE_TTL_SECONDS", "5")).seconds
  rescue ArgumentError
    5.seconds
  end
end
