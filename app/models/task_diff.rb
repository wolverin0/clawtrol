class TaskDiff < ApplicationRecord
  belongs_to :task

  validates :file_path, presence: true, uniqueness: { scope: :task_id }
  validates :diff_type, inclusion: { in: %w[modified added deleted] }

  # Parse the unified diff into structured lines for rendering
  def parsed_lines
    return [] if diff_content.blank?

    lines = []
    old_line_num = nil
    new_line_num = nil

    diff_content.each_line.with_index do |line, idx|
      line = line.chomp

      # Parse hunk header: @@ -start,count +start,count @@
      if line.start_with?("@@")
        match = line.match(/@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/)
        if match
          old_line_num = match[1].to_i
          new_line_num = match[2].to_i
        end
        lines << { type: :hunk, content: line, old_num: nil, new_num: nil }
        next
      end

      # Skip diff header lines
      next if line.start_with?("---", "+++", "diff ", "index ")

      case line[0]
      when "-"
        lines << { type: :deletion, content: line[1..], old_num: old_line_num, new_num: nil }
        old_line_num += 1 if old_line_num
      when "+"
        lines << { type: :addition, content: line[1..], old_num: nil, new_num: new_line_num }
        new_line_num += 1 if new_line_num
      when " ", nil
        content = line[0] == " " ? line[1..] : line
        lines << { type: :context, content: content, old_num: old_line_num, new_num: new_line_num }
        old_line_num += 1 if old_line_num
        new_line_num += 1 if new_line_num
      else
        # Other lines (e.g., "\ No newline at end of file")
        lines << { type: :meta, content: line, old_num: nil, new_num: nil }
      end
    end

    lines
  end

  # Group lines into collapsible sections
  # Shows CONTEXT_LINES before/after each change block
  CONTEXT_LINES = 3

  def grouped_lines
    parsed = parsed_lines
    return [] if parsed.empty?

    groups = []
    current_group = { type: :changes, lines: [] }
    context_buffer = []

    parsed.each do |line|
      case line[:type]
      when :hunk
        # Flush any pending context as collapsed
        if context_buffer.length > CONTEXT_LINES * 2
          # Add first N lines to previous group
          current_group[:lines].concat(context_buffer.first(CONTEXT_LINES))
          groups << current_group unless current_group[:lines].empty?

          # Create collapsed group for middle
          middle = context_buffer[CONTEXT_LINES...-CONTEXT_LINES]
          groups << { type: :collapsed, lines: middle, count: middle.length } if middle&.any?

          # Start new group with last N lines
          current_group = { type: :changes, lines: context_buffer.last(CONTEXT_LINES) }
        else
          current_group[:lines].concat(context_buffer)
        end
        context_buffer = []

        groups << current_group unless current_group[:lines].empty?
        current_group = { type: :changes, lines: [line] }

      when :context
        context_buffer << line

      when :addition, :deletion
        # Flush context buffer
        if context_buffer.length > CONTEXT_LINES
          current_group[:lines].concat(context_buffer.first(CONTEXT_LINES))
          groups << current_group unless current_group[:lines].empty?

          # Collapsed middle
          middle = context_buffer[CONTEXT_LINES..-1]
          if middle.length > CONTEXT_LINES
            collapsed = middle[0...-CONTEXT_LINES]
            groups << { type: :collapsed, lines: collapsed, count: collapsed.length }
            current_group = { type: :changes, lines: middle.last(CONTEXT_LINES) }
          else
            current_group = { type: :changes, lines: middle }
          end
        else
          current_group[:lines].concat(context_buffer)
        end
        context_buffer = []
        current_group[:lines] << line

      when :meta
        current_group[:lines].concat(context_buffer)
        context_buffer = []
        current_group[:lines] << line
      end
    end

    # Flush remaining
    if context_buffer.any?
      if context_buffer.length > CONTEXT_LINES
        current_group[:lines].concat(context_buffer.first(CONTEXT_LINES))
        groups << current_group unless current_group[:lines].empty?

        collapsed = context_buffer[CONTEXT_LINES..-1]
        groups << { type: :collapsed, lines: collapsed, count: collapsed.length } if collapsed.any?
      else
        current_group[:lines].concat(context_buffer)
        groups << current_group unless current_group[:lines].empty?
      end
    else
      groups << current_group unless current_group[:lines].empty?
    end

    groups
  end

  # Return a properly formatted unified diff string for diff2html.js
  # Ensures diff/--- /+++ headers are present
  def unified_diff_string
    return "" if diff_content.blank?

    content = diff_content.strip
    
    # If content already has diff headers, return as-is
    return content if content.start_with?("diff --git") || content.start_with?("--- ")

    # Otherwise, wrap with proper unified diff headers
    a_path = diff_type == "added" ? "/dev/null" : "a/#{file_path}"
    b_path = diff_type == "deleted" ? "/dev/null" : "b/#{file_path}"

    header = "diff --git a/#{file_path} b/#{file_path}\n"
    header += "--- #{a_path}\n"
    header += "+++ #{b_path}\n"

    header + content
  end

  # Stats for display
  def stats
    additions = 0
    deletions = 0

    parsed_lines.each do |line|
      case line[:type]
      when :addition then additions += 1
      when :deletion then deletions += 1
      end
    end

    { additions: additions, deletions: deletions }
  end
end
