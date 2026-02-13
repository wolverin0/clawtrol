require "open3"

class GenerateDiffsJob < ApplicationJob
  queue_as :default

  def perform(task_id, file_paths)
    task = Task.find_by(id: task_id)
    return unless task

    project_dir = task.board&.project_path.presence || File.expand_path("~/.openclaw/workspace")
    return unless Dir.exist?(project_dir)

    file_paths.each do |file_path|
      generate_diff_for_file(task, file_path, project_dir)
    rescue StandardError => e
      Rails.logger.warn("[GenerateDiffsJob] Failed to generate diff for #{file_path}: #{e.class}: #{e.message}")
    end
  end

  private

  def generate_diff_for_file(task, file_path, project_dir)
    # Resolve the full path
    full_path = file_path.start_with?("/") ? file_path : File.join(project_dir, file_path)

    # Check if file exists
    file_exists = File.exist?(full_path)

    # Try to get git diff
    diff_content = nil
    diff_type = "modified"

    if Dir.exist?(File.join(project_dir, ".git"))
      # Get the git diff for this file (staged + unstaged changes)
      stdout, status = Open3.capture2(
        "git", "diff", "HEAD~1", "--", file_path,
        chdir: project_dir
      )

      if status.success? && stdout.present?
        diff_content = stdout
        diff_type = "modified"
      else
        # Check if it's a new file (untracked or recently added)
        stdout_status, = Open3.capture2(
          "git", "status", "--porcelain", "--", file_path,
          chdir: project_dir
        )

        if stdout_status.start_with?("A") || stdout_status.start_with?("??")
          diff_type = "added"
          if file_exists
            # Show entire file as additions
            content = File.read(full_path, encoding: "UTF-8") rescue nil
            if content
              lines = content.lines.map { |l| "+#{l.chomp}" }.join("\n")
              diff_content = "@@ -0,0 +1,#{content.lines.count} @@\n#{lines}"
            end
          end
        elsif stdout_status.start_with?("D")
          diff_type = "deleted"
          # Get the deleted content from git
          stdout_show, = Open3.capture2(
            "git", "show", "HEAD:#{file_path}",
            chdir: project_dir
          )
          if stdout_show.present?
            lines = stdout_show.lines.map { |l| "-#{l.chomp}" }.join("\n")
            diff_content = "@@ -1,#{stdout_show.lines.count} +0,0 @@\n#{lines}"
          end
        end
      end
    end

    # Fallback: if no git diff but file exists, treat as new file
    if diff_content.blank? && file_exists
      content = File.read(full_path, encoding: "UTF-8") rescue nil
      if content
        diff_type = "added"
        lines = content.lines.map { |l| "+#{l.chomp}" }.join("\n")
        diff_content = "@@ -0,0 +1,#{content.lines.count} @@\n#{lines}"
      end
    end

    return if diff_content.blank?

    # Upsert the diff record
    task_diff = task.task_diffs.find_or_initialize_by(file_path: file_path)
    task_diff.update!(
      diff_content: diff_content,
      diff_type: diff_type
    )
  end
end
