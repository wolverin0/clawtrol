# frozen_string_literal: true

# Resolves OpenClaw session IDs from session keys by scanning transcript files.
#
# Extracted from Api::V1::TasksController to enable reuse across controllers
# and services that need to map task → session relationships.
#
# Usage:
#   SessionResolverService.resolve_from_key(session_key, task_id: 42)
#   SessionResolverService.scan_for_task(task_id)
#
class SessionResolverService
  SEARCH_LOOKBACK = 7.days
  RECENT_FILE_LIMIT = 30
  SAMPLE_READ_SIZE = 5_000

  # Resolve session_id (UUID) from session_key by scanning transcript files.
  #
  # The OpenClaw gateway stores transcripts as {sessionId}.jsonl.
  # Subagent prompts start with "## Task #ID:" which we can match.
  #
  # @param session_key [String] the session key to search for
  # @param task_id [Integer, nil] the task ID to match in transcripts
  # @return [String, nil] the session_id UUID, or nil if not found
  def self.resolve_from_key(session_key, task_id:)
    return nil if session_key.blank? || task_id.blank?

    sessions_dir = TranscriptParser.sessions_dir
    return nil unless Dir.exist?(sessions_dir)

    task_patterns = ["Task ##{task_id}:", "## Task ##{task_id}:"]
    session_key_patterns = [session_key.to_s, "\"session_key\":\"#{session_key}\""]
    cutoff_time = SEARCH_LOOKBACK.ago

    # Search active .jsonl files (most recent first for faster hits)
    session_id = search_files(
      Dir.glob(File.join(sessions_dir, "*.jsonl")),
      cutoff_time,
      task_id: task_id,
      task_patterns: task_patterns,
      session_key_patterns: session_key_patterns
    ) { |file| File.basename(file, ".jsonl") }

    return session_id if session_id

    # Also check archived files (.deleted. suffix) if not found
    search_files(
      Dir.glob(File.join(sessions_dir, "*.jsonl.deleted.*")),
      cutoff_time,
      task_id: task_id,
      task_patterns: task_patterns,
      session_key_patterns: session_key_patterns
    ) { |file| File.basename(file).sub(/\.jsonl\.deleted\..+$/, "") }
  rescue StandardError => e
    Rails.logger.warn("[SessionResolverService] resolve_from_key error: #{e.message}")
    nil
  end

  # Scan recent transcript files for references to a task ID.
  #
  # Used as a last-resort fallback when agent_session_key is not available.
  # Agents include the task ID in their curl commands and prompt context.
  #
  # @param task_id [Integer] the task ID to search for
  # @return [String, nil] the session_id UUID, or nil if not found
  def self.scan_for_task(task_id)
    return nil if task_id.blank?

    sessions_dir = TranscriptParser.sessions_dir
    return nil unless Dir.exist?(sessions_dir)

    files = Dir.glob(File.join(sessions_dir, "*.jsonl"))
      .sort_by { |f| -File.mtime(f).to_i }
      .first(RECENT_FILE_LIMIT)

    patterns = [
      "Task ##{task_id}",
      "## Task ##{task_id}:",
      "task_id\":#{task_id}",
      "Task ID: #{task_id}"
    ]

    files.each do |file|
      sample = File.read(file, SAMPLE_READ_SIZE) rescue next

      # Guardrail: ignore interactive Telegram/chat transcripts to avoid
      # mis-linking the orchestrator conversation as task agent activity.
      next if sample.include?("Mission Control") || sample.include?("telegram:group")

      if patterns.any? { |p| sample.include?(p) }
        session_id = File.basename(file, ".jsonl")
        # Don't return if this session_id is already linked to another task
        if Task.where(agent_session_id: session_id).where.not(id: task_id).none?
          Rails.logger.info("[SessionResolverService] Found session_id=#{session_id} for task #{task_id}")
          return session_id
        end
      end
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("[SessionResolverService] scan_for_task error for task #{task_id}: #{e.message}")
    nil
  end

  # Private class methods

  def self.search_files(file_paths, cutoff_time, task_id:, task_patterns:, session_key_patterns:, &id_extractor)
    sorted = file_paths.sort_by { |f| -File.mtime(f).to_i }

    sorted.each do |file|
      next if File.mtime(file) < cutoff_time

      # Read first 15 lines — task prompt/session context are in initial user message.
      first_lines = []
      File.foreach(file).with_index do |line, idx|
        break if idx >= 15
        first_lines << line
      end
      content_sample = first_lines.join
      next if interactive_chat_sample?(content_sample)

      has_session_key = session_key_patterns.any? { |p| p.present? && content_sample.include?(p) }
      has_task_marker = task_patterns.any? { |p| p.present? && content_sample.include?(p) }
      next unless has_session_key && has_task_marker

      session_id = id_extractor.call(file)
      next if Task.where(agent_session_id: session_id).where.not(id: task_id).exists?

      Rails.logger.info("[SessionResolverService] Found session_id=#{session_id} (session_key=#{has_session_key} task_marker=#{has_task_marker}) in #{File.basename(file)}")
      return session_id
    end

    nil
  end

  def self.interactive_chat_sample?(sample)
    return true if sample.include?("Mission Control")
    return true if sample.include?("telegram:group")
    return true if sample.include?("requester channel: telegram")

    false
  end

  private_class_method :search_files, :interactive_chat_sample?
end
