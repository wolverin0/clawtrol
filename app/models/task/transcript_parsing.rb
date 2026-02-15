# frozen_string_literal: true

require "open3"

module Task::TranscriptParsing
  extend ActiveSupport::Concern

  included do
    after_update :try_transcript_capture, if: :saved_change_to_status?
  end

  def transcript_path
    return nil if agent_session_id.blank?
    sid = agent_session_id.to_s
    return nil unless sid.match?(/\A[a-zA-Z0-9_\-]+\z/)

    File.expand_path("~/.openclaw/agents/main/sessions/#{sid}.jsonl")
  end

  def transcript_exists?
    path = transcript_path
    path.present? && File.exist?(path)
  end

  def normalized_output_files(files)
    Array(files)
      .flatten
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
  end

  def extract_output_files_from_findings(findings)
    text = findings.to_s
    return [] if text.blank?

    path_regex = %r{(?<![\w./-])(?:\./|/)?[\w@%+=:,~.-]+(?:/[\w@%+=:,~.-]+)+\.[A-Za-z0-9_]{1,10}(?![\w./-])}

    text.scan(path_regex)
        .map { |path| path.to_s.gsub(%r{\A\./}, "") }
        .reject { |path| path.include?("//") }
        .uniq
  end

  def extract_output_files_from_transcript_commit
    return [] unless transcript_exists?

    commit = latest_commit_hash_from_transcript
    return [] if commit.blank?

    project_dir = board&.project_path.presence || File.expand_path("~/.openclaw/workspace")
    return [] unless Dir.exist?(project_dir)
    return [] unless Dir.exist?(File.join(project_dir, ".git"))

    stdout, status = Open3.capture2("git", "show", "--name-only", "--pretty=format:", commit, chdir: project_dir)
    return [] unless status.success?

    stdout.lines
          .map(&:strip)
          .reject(&:blank?)
          .reject { |line| line.start_with?("commit ") }
          .uniq
  rescue StandardError => e
    Rails.logger.warn("[Task##{id}] Failed to extract output_files from git commit: #{e.class}: #{e.message}")
    []
  end

  def backfill_output_files_from_transcript_commit!
    files = extract_output_files_from_transcript_commit
    return [] if files.blank?

    merged = normalized_output_files((output_files || []) + files)
    update!(output_files: merged) if merged != (output_files || [])
    merged
  end

  def latest_commit_hash_from_transcript
    path = transcript_path
    return nil unless path.present? && File.exist?(path)

    commit_hashes = []

    File.foreach(path) do |line|
      line.scan(/\bcommit\s+([0-9a-f]{7,40})\b/i) { |m| commit_hashes << m.first }
      line.scan(/\b[0-9a-f]{40}\b/i) { |m| commit_hashes << m }
    end

    commit_hashes.last&.downcase
  rescue StandardError => e
    Rails.logger.warn("[Task##{id}] Failed to parse transcript for commit hash: #{e.class}: #{e.message}")
    nil
  end

  private

  # Auto-capture agent output from transcripts when task completes without proper agent_complete
  def try_transcript_capture
    return unless %w[in_review done].include?(self.status)
    # Only capture if there's no agent output yet
    return if description.to_s.include?("## Agent Output")
    return if output_files.present? && output_files.any?

    TranscriptCaptureJob.perform_later(id)
  end
end
