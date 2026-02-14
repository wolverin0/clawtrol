# frozen_string_literal: true

class FactoryController < ApplicationController

  def index
    @loops = current_user.factory_loops.ordered
  end

  # Factory playground progress page: git log, improvement log, diffs
  def playground
    playground_path = Rails.root.to_s

    # Git log (last 50 factory commits)
    @git_log = safe_shell("git", "-C", playground_path, "log", "--oneline", "--format=%H|%h|%s|%ai", "-50")
      .split("\n")
      .filter_map do |line|
        parts = line.split("|", 4)
        next unless parts.size == 4
        { full_hash: parts[0], short_hash: parts[1], message: parts[2], date: parts[3] }
      end

    # Improvement log content
    log_path = File.join(playground_path, "IMPROVEMENT_LOG.md")
    @improvement_log = File.exist?(log_path) ? File.read(log_path, encoding: "utf-8") : "No IMPROVEMENT_LOG.md found."
    @improvement_log = @improvement_log.truncate(100_000)

    # Factory backlog
    backlog_path = File.join(playground_path, "FACTORY_BACKLOG.md")
    @backlog = File.exist?(backlog_path) ? File.read(backlog_path, encoding: "utf-8") : "No FACTORY_BACKLOG.md found."
    @backlog = @backlog.truncate(50_000)

    # Stats
    @total_commits = safe_shell("git", "-C", playground_path, "rev-list", "--count", "HEAD").strip.to_i
    @factory_commits = safe_shell("git", "-C", playground_path, "rev-list", "--count", "--all", "--grep=[factory]").strip.to_i rescue 0
    @files_changed = safe_shell("git", "-C", playground_path, "diff", "--stat", "HEAD~10", "HEAD", "--", "app/", "test/", "db/").lines.last&.strip || "N/A"

    # Diff for a specific commit (via params)
    @selected_diff = nil
    if params[:commit].present? && params[:commit].match?(/\A[a-f0-9]{7,40}\z/)
      @selected_diff = safe_shell("git", "-C", playground_path, "show", "--stat", "--patch", params[:commit])
      @selected_diff = @selected_diff.truncate(50_000)
      @selected_commit = params[:commit]
    end
  end

  def create
    loop = current_user.factory_loops.new(factory_loop_params)
    if loop.save
      respond_to do |format|
        format.html { redirect_to factory_path, notice: "Factory loop created" }
        format.json { render json: { success: true, id: loop.id, name: loop.name } }
      end
    else
      respond_to do |format|
        format.html { redirect_to factory_path, alert: loop.errors.full_messages.join(", ") }
        format.json { render json: { success: false, error: loop.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def update
    loop = current_user.factory_loops.find(params[:id])
    if loop.update(factory_loop_params)
      respond_to do |format|
        format.html { redirect_to factory_path, notice: "Factory loop updated" }
        format.json { render json: { success: true, id: loop.id } }
      end
    else
      respond_to do |format|
        format.html { redirect_to factory_path, alert: loop.errors.full_messages.join(", ") }
        format.json { render json: { success: false, error: loop.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    loop = current_user.factory_loops.find(params[:id])
    loop.destroy
    respond_to do |format|
      format.html { redirect_to factory_path, notice: "Factory loop deleted" }
      format.json { render json: { success: true } }
    end
  end

  def play
    loop = current_user.factory_loops.find(params[:id])
    loop.play!
    render json: { success: true, status: loop.status }
  end

  def pause
    loop = current_user.factory_loops.find(params[:id])
    loop.pause!
    render json: { success: true, status: loop.status }
  end

  def stop
    loop = current_user.factory_loops.find(params[:id])
    loop.stop!
    render json: { success: true, status: loop.status }
  end

  def bulk_play
    ids = params[:ids] || []
    current_user.factory_loops.where(id: ids).find_each(&:play!)
    render json: { success: true }
  end

  def bulk_pause
    current_user.factory_loops.where(status: :playing).find_each(&:pause!)
    render json: { success: true }
  end

  private

  def factory_loop_params
    params.require(:factory_loop).permit(:name, :slug, :description, :icon, :interval_ms, :model, :fallback_model, :system_prompt, config: {}, state: {})
  end

  # Safe shell execution with timeout and error handling
  def safe_shell(*args)
    IO.popen(args, err: [:child, :out]) do |io|
      io.read(100_000) || ""
    end
  rescue StandardError => e
    Rails.logger.warn("[FactoryController] Shell command failed: #{e.message}")
    ""
  end
end
