# Fallback job: captures agent output from OpenClaw session transcripts
# when agent_complete wasn't called properly.
#
# Triggered when a task moves to in_review or done without agent output.
# Scans recent transcript files for matching task references.
class TranscriptCaptureJob < ApplicationJob
  queue_as :default

  SESSIONS_DIR = File.expand_path("~/.openclaw/agents/main/sessions")
  WORKSPACE_DIR = File.expand_path("~/.openclaw/workspace")

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task

    # Skip if task already has agent output
    return if task.description.to_s.include?("## Agent Output")
    return if task.agent_session_id.present? && transcript_exists?(task.agent_session_id)

    Rails.logger.info("[TranscriptCapture] Scanning for output for task ##{task.id}: #{task.title}")

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
    path = File.join(SESSIONS_DIR, "#{session_id}.jsonl")
    # Also check archived
    unless File.exist?(path)
      archived = Dir.glob(File.join(SESSIONS_DIR, "#{session_id}.jsonl.deleted.*")).first
      path = archived if archived
    end
    return nil unless path && File.exist?(path)

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
    output_text = nil
    written_files = []

    File.foreach(path) do |line|
      begin
        data = JSON.parse(line.strip)
        next unless data["type"] == "message"
        msg = data["message"]
        next unless msg

        # Extract last assistant text as output summary
        if msg["role"] == "assistant"
          content = msg["content"]
          if content.is_a?(Array)
            texts = content.select { |c| c["type"] == "text" }.map { |c| c["text"] }
            output_text = texts.last if texts.any?

            # Extract files from tool calls (Write/Edit tools)
            content.each do |item|
              if item["type"] == "toolCall" && %w[Write Edit write edit].include?(item["name"])
                input = item["input"] || {}
                fp = input["file_path"] || input["path"] || input["file"]
                written_files << fp if fp.present?
              end
            end
          elsif content.is_a?(String) && content.length > 20
            output_text = content
          end
        end

        # Also extract from tool results that write files
        if msg["role"] == "toolResult"
          content = msg["content"]
          if content.is_a?(Array)
            content.each do |item|
              if item["type"] == "text" && item["text"].to_s.include?("Successfully")
                # Try to extract file path from success messages
                match = item["text"].match(/(?:wrote|created|edited|saved)\s+(?:to\s+)?[`"']?([^\s`"']+)[`"']?/i)
                written_files << match[1] if match
              end
            end
          end
        end
      rescue JSON::ParserError
        next
      end
    end

    return nil if output_text.blank? && written_files.empty?

    {
      output: output_text&.truncate(3000),
      files: written_files.uniq.reject(&:blank?)
    }
  end

  def apply_captured_output(task, result)
    updates = {}

    if result[:output].present?
      new_description = task.description.to_s
      unless new_description.include?("## Agent Output")
        new_description += "\n\n## Agent Output\n"
      end
      new_description += "\n_(Auto-captured from transcript)_\n\n#{result[:output]}"
      updates[:description] = new_description
    end

    if result[:files].present?
      existing = task.output_files || []
      updates[:output_files] = (existing + result[:files]).uniq
    end

    if updates.any?
      task.update!(updates)
      Rails.logger.info("[TranscriptCapture] Captured output for task ##{task.id}: #{result[:output]&.truncate(100)}, #{result[:files].size} files")
    end
  end
end
