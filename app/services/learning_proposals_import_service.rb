# frozen_string_literal: true

require "digest"
require "pathname"

# Imports pending self-audit learning entries from OpenClaw workspace markdown
# files into ClawTrol LearningProposal records.
#
# Source files:
#   ~/.openclaw/workspace/memory/learnings/*.md
#
# This keeps the Learning Inbox populated even when the external pipeline writes
# markdown learnings but does not POST directly to /api/v1/learning_proposals.
class LearningProposalsImportService
  Entry = Struct.new(
    :source_file,
    :date,
    :title,
    :tag,
    :context,
    :error,
    :correction,
    :trigger,
    :recurrence,
    :status,
    keyword_init: true
  )

  DEFAULT_WORKSPACE_ROOT = ENV.fetch("OPENCLAW_WORKSPACE_ROOT", File.expand_path("~/.openclaw/workspace"))
  LEARNINGS_RELATIVE_DIR = "memory/learnings"
  DEFAULT_RECURRENCE_THRESHOLD = Integer(ENV.fetch("LEARNING_PROPOSALS_MIN_RECURRENCE", "2"))
  PENDING_STATUSES = %w[pending pending_review].freeze

  def initialize(user, workspace_root: DEFAULT_WORKSPACE_ROOT)
    @user = user
    @workspace_root = Pathname.new(workspace_root)
  end

  def call(recurrence_threshold: DEFAULT_RECURRENCE_THRESHOLD)
    return { created: 0, skipped: 0, errors: [ "missing_user" ] } unless @user
    return { created: 0, skipped: 0, errors: [ "learnings_directory_not_found" ] } unless learnings_dir.directory?

    created = 0
    skipped = 0
    errors = []

    parse_entries.each do |entry|
      if entry.recurrence.to_i < recurrence_threshold
        skipped += 1
        next
      end

      signature = entry_signature(entry)
      reason = "learning_entry:#{signature}"
      if @user.learning_proposals.exists?(reason: reason)
        skipped += 1
        next
      end

      target_file = target_file_for(entry)
      current_content = read_target_file(target_file)
      block = proposal_block(entry, signature)

      if current_content.include?("learning_entry:#{signature}")
        skipped += 1
        next
      end

      proposal = @user.learning_proposals.build(
        title: proposal_title(entry),
        proposed_by: "self-audit",
        target_file: target_file,
        current_content: current_content,
        proposed_content: append_block(current_content, block),
        diff_preview: block,
        reason: reason
      )
      proposal.save!
      created += 1
    rescue StandardError => e
      errors << "#{entry.source_file}: #{e.class.name} #{e.message}"
    end

    { created: created, skipped: skipped, errors: errors }
  end

  private

  def learnings_dir
    @workspace_root.join(LEARNINGS_RELATIVE_DIR)
  end

  def parse_entries
    files = Dir.glob(learnings_dir.join("*.md")).sort
    files.reject! { |path| %w[README.md schema.md].include?(File.basename(path)) }
    files.flat_map { |path| parse_file(path) }
  end

  def parse_file(path)
    lines = File.readlines(path, chomp: true)
    blocks = []
    current = nil

    lines.each do |line|
      if (header = line.match(/^##\s+\[(\d{4}-\d{2}-\d{2})\]\s+(.+)$/))
        blocks << current if current
        current = { date: header[1], title: header[2].strip, lines: [] }
      elsif current
        current[:lines] << line
      end
    end
    blocks << current if current

    blocks.filter_map { |block| build_entry(path, block) }
  end

  def build_entry(path, block)
    status = extract_field(block[:lines], /\*\*(?:Estado|Status):\*\*\s*(.+)$/i).to_s.downcase
    return nil unless PENDING_STATUSES.include?(status)

    title = block[:title]
    Entry.new(
      source_file: path,
      date: block[:date],
      title: title,
      tag: title[/^\[([^\]]+)\]/, 1].to_s.downcase.presence || "general",
      context: extract_field(block[:lines], /\*\*(?:Contexto|Context):\*\*\s*(.+)$/i),
      error: extract_field(block[:lines], /\*\*(?:Error|Error cometido):\*\*\s*(.+)$/i),
      correction: extract_field(block[:lines], /\*\*(?:Corrección|Correction):\*\*\s*(.+)$/i),
      trigger: extract_field(block[:lines], /\*\*Trigger:\*\*\s*(.+)$/i),
      recurrence: extract_field(block[:lines], /\*\*Recurrencia:\*\*\s*(\d+)/i).to_i,
      status: status
    )
  end

  def extract_field(lines, pattern)
    line = lines.find { |candidate| candidate.match?(pattern) }
    return nil unless line

    line.match(pattern)&.captures&.first.to_s.strip
  end

  def entry_signature(entry)
    raw = [
      entry.date,
      entry.tag,
      entry.title,
      entry.error,
      entry.correction,
      entry.trigger
    ].join("|")
    Digest::SHA256.hexdigest(raw)[0, 16]
  end

  def target_file_for(entry)
    case entry.tag
    when "local_paths"
      "mind/DECISIONS.md"
    else
      "mind/ERRORS.md"
    end
  end

  def read_target_file(target_file)
    absolute = @workspace_root.join(target_file)
    return "" unless absolute.exist?

    File.read(absolute)
  end

  def append_block(current_content, block)
    base = current_content.to_s
    separator = base.rstrip.empty? ? "" : "\n\n"
    "#{base.rstrip}#{separator}#{block}\n"
  end

  def proposal_title(entry)
    "Self-audit learning: #{entry.tag} (#{entry.date})"
  end

  def proposal_block(entry, signature)
    [
      "### [#{entry.date}] #{entry.tag} (learning_entry:#{signature})",
      "- Source: #{entry.source_file}",
      "- Title: #{entry.title}",
      "- Error: #{entry.error}",
      "- Correction: #{entry.correction}",
      "- Trigger: #{entry.trigger}",
      "- Recurrence: #{entry.recurrence}"
    ].join("\n")
  end
end
