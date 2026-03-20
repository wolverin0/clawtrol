# frozen_string_literal: true

# SessionAutoLinkerJob — Auto-links OpenClaw session transcripts to in_progress tasks
# that have no agent_session_id set.
#
# Problem solved:
#   When the orchestrator spawns a subagent for a ClawTrol task, it often forgets (or
#   races) to call link_session. The task sits in_progress with agent_session_id=nil,
#   so the ClawTrol modal shows nothing — zero observability for Snake.
#
# Mechanism:
#   Every 3 minutes, find tasks that:
#     1. Are in_progress with agent_session_id = nil
#     2. Have been claimed/created for at least LINK_GRACE_SECONDS
#   For each task, scan recent JSONL session files (including .deleted archives).
#   Scores each candidate with discriminators:
#     - CRITICAL: session start time — sessions started AFTER task creation are workers
#     - CRITICAL: sessions that called link_session FOR THIS TASK are orchestrators (penalized)
#     - Content signals: task ID in API paths, task name match, tool call signatures
#   When best score >= MIN_SCORE, auto-links.
#
# This is fully automatic — no agent cooperation required.
class SessionAutoLinkerJob < ApplicationJob
  queue_as :default

  LINK_GRACE_SECONDS    = 3.minutes  # Give agent_complete a chance to fire first
  SCAN_WINDOW_HOURS     = 4.hours    # Only look at transcripts from the last N hours
  SPAWN_WINDOW_SECONDS  = 5.minutes  # Session must start within this window after task creation
  MAX_TASKS_PER_RUN     = 20
  MIN_SCORE             = 10         # Minimum confidence threshold
  HEAD_TAIL_BYTES       = 50_000
  LARGE_FILE_BYTES      = 200_000
  SESSIONS_DIR          = TranscriptParser::SESSIONS_DIR

  def perform
    return unless Dir.exist?(SESSIONS_DIR)

    task_anchor = Time.current - LINK_GRACE_SECONDS
    orphan_tasks = Task
      .where(status: :in_progress, agent_session_id: nil)
      .where("COALESCE(agent_claimed_at, created_at) < ?", task_anchor)
      .order(Arel.sql("COALESCE(agent_claimed_at, created_at) ASC"))
      .limit(MAX_TASKS_PER_RUN)

    return if orphan_tasks.empty?

    Rails.logger.info("[SessionAutoLinker] #{orphan_tasks.size} unlinked in_progress task(s)")

    cutoff = Time.current - SCAN_WINDOW_HOURS
    active_files  = Dir.glob(File.join(SESSIONS_DIR, "*.jsonl")).select { |f| File.mtime(f) > cutoff }
    deleted_files = Dir.glob(File.join(SESSIONS_DIR, "*.jsonl.deleted.*")).select { |f| File.mtime(f) > cutoff }
    all_files     = (active_files + deleted_files).sort_by { |f| -File.mtime(f).to_i }

    return Rails.logger.debug("[SessionAutoLinker] No recent JSONL files") if all_files.empty?

    orphan_tasks.each { |task| link_session_for_task(task, all_files) }
  end

  private

  def link_session_for_task(task, all_files)
    # Use created_at as fallback when agent_claimed_at is nil
    task_start = task.agent_claimed_at || task.created_at
    candidates = []

    all_files.each do |path|
      next if File.mtime(path) < task_start - 2.minutes

      session_id = File.basename(path).split(".jsonl").first
      next unless session_id.match?(/\A[0-9a-f\-]{36}\z/i)

      content = read_file_content(path)
      next if content.nil?

      session_started_at = parse_session_start_time(content)
      score = compute_score(path, task, content, task_start, session_started_at)
      candidates << { session_id: session_id, score: score } if score > 0
    rescue => e
      Rails.logger.debug("[SessionAutoLinker] Skipping #{path}: #{e.message}")
    end

    return Rails.logger.debug("[SessionAutoLinker] No candidates for task ##{task.id}") if candidates.empty?

    best = candidates.max_by { |c| c[:score] }

    if best[:score] < MIN_SCORE
      Rails.logger.debug("[SessionAutoLinker] Task ##{task.id}: best score=#{best[:score]} < #{MIN_SCORE} — skip")
      return
    end

    Rails.logger.info("[SessionAutoLinker] Linking task ##{task.id} (#{task.name.truncate(50)}) → #{best[:session_id]} (score=#{best[:score]})")
    task.update_column(:agent_session_id, best[:session_id])
  rescue => e
    Rails.logger.error("[SessionAutoLinker] task ##{task.id}: #{e.class}: #{e.message}")
  end

  # Read file content safely — head+tail sample for large files.
  def read_file_content(path)
    file_size = File.size(path)
    if file_size <= LARGE_FILE_BYTES
      File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace)
    else
      File.open(path, encoding: "UTF-8", invalid: :replace, undef: :replace) do |f|
        head = f.read(HEAD_TAIL_BYTES) || ""
        begin
          f.seek(-HEAD_TAIL_BYTES, IO::SEEK_END)
        rescue Errno::EINVAL
          return head
        end
        tail = f.read(HEAD_TAIL_BYTES) || ""
        head + tail
      end
    end
  rescue => e
    Rails.logger.debug("[SessionAutoLinker] read error #{path}: #{e.message}")
    nil
  end

  # Parse session start time from JSONL first line ({"type":"init","timestamp":...})
  # Returns nil if not parseable.
  def parse_session_start_time(content)
    first_line = content.lines.first.to_s.strip
    return nil if first_line.blank?
    data = JSON.parse(first_line)
    ts = data["timestamp"]
    ts.present? ? Time.parse(ts) : nil
  rescue
    nil
  end

  def compute_score(path, task, content, task_start, session_started_at)
    score = 0
    id    = task.id.to_s
    name  = task.name.to_s

    # ── TIMING DISCRIMINATOR (most reliable signal) ──────────────────────────
    if session_started_at
      time_after_task = session_started_at - task_start

      if time_after_task >= 0 && time_after_task <= SPAWN_WINDOW_SECONDS
        # Session started WITHIN 5 minutes after task creation/claim → spawned for this task
        score += 25
      elsif time_after_task > SPAWN_WINDOW_SECONDS
        # Session started too long after — unrelated session
        score -= 5
      else
        # Session started BEFORE task — likely the orchestrator (main session)
        # The earlier it started, the more likely it's the long-running main session
        score -= 15 if time_after_task < -300  # more than 5 min before
        score -= 5  if time_after_task.between?(-300, 0)
      end
    end

    # ── ORCHESTRATOR DETECTION PENALTY ───────────────────────────────────────
    # If this session called link_session for THIS task, it's the orchestrator
    # that linked a subagent — should NOT be linked as the worker itself.
    if content.include?("tasks/#{id}/link_session") || content.include?("link_session.*#{id}")
      score -= 20
    end

    # ── CONTENT SIGNALS ───────────────────────────────────────────────────────
    # URL path API calls (high confidence — agent actively called the task API)
    score += 12 if content.include?("tasks/#{id}/") || content.include?("tasks/#{id}\"")

    # JSON payload with explicit task_id field
    score += 10 if content.include?("\"task_id\":#{id}") || content.include?("\"task_id\": #{id}")

    # Hash-reference with word boundary (avoid #7310 matching #731)
    score += 5 if content.match?(/\##{Regexp.escape(id)}(?!\d)/)

    # Text patterns
    score += 4 if content.include?("task ##{id}") || content.include?("task_id=#{id}")

    # Task name present in content (worker received task details in prompt)
    task_name_snippet = name.first(50).strip
    score += 8 if task_name_snippet.length >= 10 && content.include?(task_name_snippet)

    # clawtrol_move or clawtrol_task tool calls with this task_id (worker signature)
    score += 6 if content.include?("\"task_id\":\"#{id}\"") || content.include?("task_id.*\"#{id}\"")

    score
  end
end
