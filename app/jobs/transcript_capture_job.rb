# frozen_string_literal: true

# Fallback job: captures agent output from OpenClaw session transcripts
# when agent_complete wasn't called properly.
#
# Triggered when a task moves to in_review or done without agent output.
# Scans recent transcript files for matching task references.
class TranscriptCaptureJob < ApplicationJob
  queue_as :default

  SESSIONS_DIR = TranscriptParser::SESSIONS_DIR
  WORKSPACE_DIR = File.expand_path("~/.openclaw/workspace")

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task

    # P0 Data Contract: check TaskRun for output, fall back to description parsing
    if task.has_agent_output?
      output = task.agent_output_text.to_s
      return unless output.include?("Agent completed (no findings provided)")
    end
    return if task.agent_session_id.present? && transcript_exists?(task.agent_session_id)

    Rails.logger.info("[TranscriptCapture] Scanning for output for task ##{task.id}: #{task.name}")

    # Strategy 1: If we have a session_id, try to find the transcript
    if task.agent_session_id.present?
      result = extract_from_transcript(task.agent_session_id, task)
      if result
        apply_captured_output(task, result)
        return
      end
    end

    # Strategy 2: Scan recent transcripts for task ID references
    result = scan_recent_transcripts(task)
    if result
      apply_captured_output(task, result)
      return
    end

    Rails.logger.info("[TranscriptCapture] No transcript found for task ##{task.id}")
  end

  private

  def transcript_exists?(session_id)
    path = File.join(SESSIONS_DIR, "#{session_id}.jsonl")
    File.exist?(path)
  end

  def extract_from_transcript(session_id, task)
    path = TranscriptParser.transcript_path(session_id)
    return nil unless path

    parse_transcript(path, task)
  end

  def scan_recent_transcripts(task)
    return nil unless Dir.exist?(SESSIONS_DIR)

    # Look at transcripts modified in the last 24 hours
    cutoff = Time.current - 24.hours
    recent_files = Dir.glob(File.join(SESSIONS_DIR, "*.jsonl"))
                      .select { |f| File.mtime(f) > cutoff }
                      .sort_by { |f| -File.mtime(f).to_i }

    recent_files.each do |path|
      # Quick check: does this file mention our task ID?
      content = File.read(path, encoding: "UTF-8") rescue next
      task_ref = "tasks/#{task.id}"
      task_ref_hash = "##{task.id}"

      if content.include?(task_ref) || content.include?(task_ref_hash)
        result = parse_transcript(path, task)
        if result
          # Also capture the session ID for future reference
          session_id = File.basename(path, ".jsonl")
          task.update_column(:agent_session_id, session_id) if task.agent_session_id.blank?
          return result
        end
      end
    end

    nil
  end

  def parse_transcript(path, task)
    # Use TranscriptParser's extract_summary for output text
    output_text = TranscriptParser.extract_summary(path)

    # Fall back to last assistant text if no summary-keyword match
    if output_text.blank?
      TranscriptParser.each_entry(path) do |data, _line_num|
        next unless data["type"] == "message"
        msg = data["message"]
        next unless msg && msg["role"] == "assistant"
        text = TranscriptParser.flatten_content_text(msg["content"])
        output_text = text if text.present? && text.length > 20
      end
    end

    written_files = TranscriptParser.extract_output_files(path)

    return nil if output_text.blank? && written_files.empty?

    {
      output: output_text&.truncate(3000),
      files: written_files
    }
  end

  # P0 Data Contract: store captured output in TaskRun, NOT description
  def apply_captured_output(task, result)
    if result[:output].present?
      task_run = task.task_runs.order(created_at: :desc).first
      captured_text = "_(Auto-captured from transcript)_\n\n#{result[:output]}"

      if task_run
        task_run.update_columns(agent_output: captured_text) if task_run.agent_output.blank?
      else
        task.task_runs.create!(
          run_id: SecureRandom.uuid,
          agent_output: captured_text,
          prompt_used: task.effective_prompt,
          status: "completed"
        )
      end
    end

    if result[:files].present?
      existing = task.output_files || []
      task.update!(output_files: (existing + result[:files]).uniq)
    end

    Rails.logger.info("[TranscriptCapture] Captured output for task ##{task.id}: #{result[:output]&.truncate(100)}, #{result[:files]&.size || 0} files")
  end
end
