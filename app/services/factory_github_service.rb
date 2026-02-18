# frozen_string_literal: true

require "open3"
require "fileutils"

class FactoryGithubService
  GH_BIN = "/home/ggorbalan/.local/bin/gh"
  GIT_BIN = "/usr/bin/git"
  WORKSPACE_ROOT = File.expand_path("~/factory-workspaces")

  Result = Struct.new(:success, :message, :data, keyword_init: true) do
    def success? = success
  end

  def initialize(factory_loop)
    @loop = factory_loop
  end

  # Clone a GitHub repository and set up the workspace
  def clone!
    return Result.new(success: false, message: "No github_url configured") unless @loop.github_url.present?

    owner_repo = extract_owner_repo(@loop.github_url)
    return Result.new(success: false, message: "Invalid github_url: #{@loop.github_url}") unless owner_repo

    clone_dir = File.join(WORKSPACE_ROOT, @loop.slug)
    FileUtils.mkdir_p(WORKSPACE_ROOT)

    # If directory exists and is a valid git repo, skip clone
    if Dir.exist?(clone_dir) && File.exist?(File.join(clone_dir, ".git"))
      Rails.logger.info("[FactoryGithubService] #{clone_dir} already exists, skipping clone")
    else
      FileUtils.rm_rf(clone_dir) if Dir.exist?(clone_dir)

      stdout, stderr, status = run_git(".", "clone", @loop.github_url, clone_dir)
      unless status.success?
        return Result.new(success: false, message: "Clone failed: #{stderr.presence || stdout}")
      end
    end

    # Create and checkout work branch
    default_branch = @loop.github_default_branch.presence || "main"
    work_branch = @loop.work_branch.presence || "factory/auto"

    # Fetch and ensure we're up to date
    run_git(clone_dir, "fetch", "origin")

    # Check if work branch exists remotely or locally
    stdout, _stderr, _status = run_git(clone_dir, "branch", "-a", "--list", "*#{work_branch}*")
    branch_exists = stdout.to_s.strip.present?

    if branch_exists
      run_git(clone_dir, "checkout", work_branch)
      run_git(clone_dir, "pull", "origin", work_branch, "--rebase")
    else
      # Create from default branch
      run_git(clone_dir, "checkout", default_branch)
      run_git(clone_dir, "checkout", "-b", work_branch)
    end

    # Update the loop's workspace_path
    @loop.update!(workspace_path: clone_dir)

    # Configure hooks (reuse existing method from FactoryLoop)
    @loop.send(:configure_workspace_hooks!) if @loop.respond_to?(:configure_workspace_hooks!, true)

    Result.new(success: true, message: "Cloned to #{clone_dir}", data: { workspace_path: clone_dir })
  end

  # Sync (fetch + rebase) the workspace with origin
  def sync!
    return Result.new(success: false, message: "No github_url configured") unless @loop.github_url.present?
    return Result.new(success: false, message: "No workspace_path set") unless @loop.workspace_path.present?
    return Result.new(success: false, message: "Workspace does not exist") unless Dir.exist?(@loop.workspace_path)

    default_branch = @loop.github_default_branch.presence || "main"
    work_branch = @loop.work_branch.presence || "factory/auto"

    # Fetch latest
    stdout, stderr, status = run_git(@loop.workspace_path, "fetch", "origin")
    unless status.success?
      return Result.new(success: false, message: "Fetch failed: #{stderr.presence || stdout}")
    end

    # Rebase work branch onto origin's default branch
    stdout, stderr, status = run_git(@loop.workspace_path, "rebase", "origin/#{default_branch}")
    unless status.success?
      # Abort rebase on failure to leave clean state
      run_git(@loop.workspace_path, "rebase", "--abort")
      return Result.new(success: false, message: "Rebase failed: #{stderr.presence || stdout}")
    end

    Result.new(success: true, message: "Synced with origin/#{default_branch}")
  end

  # Push the work branch to origin
  def push!
    return Result.new(success: false, message: "No workspace_path set") unless @loop.workspace_path.present?

    work_branch = @loop.work_branch.presence || "factory/auto"

    stdout, stderr, status = run_git(@loop.workspace_path, "push", "-u", "origin", work_branch)
    unless status.success?
      return Result.new(success: false, message: "Push failed: #{stderr.presence || stdout}")
    end

    Result.new(success: true, message: "Pushed to origin/#{work_branch}")
  end

  # Create a pull request using gh CLI
  def create_pr!(title: nil, body: nil)
    return Result.new(success: false, message: "No github_url configured") unless @loop.github_url.present?

    owner_repo = extract_owner_repo(@loop.github_url)
    return Result.new(success: false, message: "Invalid github_url") unless owner_repo

    # Push changes first
    push_result = push!
    return push_result unless push_result.success?

    default_branch = @loop.github_default_branch.presence || "main"
    work_branch = @loop.work_branch.presence || "factory/auto"

    title ||= generate_pr_title
    body ||= generate_pr_body

    stdout, stderr, status = run_gh(
      "pr", "create",
      "--repo", owner_repo,
      "--head", work_branch,
      "--base", default_branch,
      "--title", title,
      "--body", body
    )

    if status.success?
      pr_url = stdout.to_s.strip
      @loop.update!(github_last_pr_at: Time.current, github_last_pr_url: pr_url)
      Result.new(success: true, message: "PR created", data: { pr_url: pr_url })
    else
      Result.new(success: false, message: "PR creation failed: #{stderr.presence || stdout}")
    end
  end

  # Check if a PR already exists for the work branch
  def pr_exists?
    return false unless @loop.github_url.present?

    owner_repo = extract_owner_repo(@loop.github_url)
    return false unless owner_repo

    work_branch = @loop.work_branch.presence || "factory/auto"

    stdout, _stderr, status = run_gh(
      "pr", "list",
      "--repo", owner_repo,
      "--head", work_branch,
      "--state", "open",
      "--json", "number"
    )

    return false unless status.success?

    # Parse JSON output
    require "json"
    prs = JSON.parse(stdout.to_s) rescue []
    prs.any?
  end

  # Check if enough successful cycles have occurred since last PR
  def pr_ready?
    return false unless @loop.github_pr_enabled?
    return false if pr_exists?

    batch_size = @loop.github_pr_batch_size || 5
    last_pr_at = @loop.github_last_pr_at

    successful_since = if last_pr_at
      @loop.factory_cycle_logs.where(status: "completed").where("finished_at > ?", last_pr_at).count
    else
      @loop.factory_cycle_logs.where(status: "completed").count
    end

    successful_since >= batch_size
  end

  private

  def extract_owner_repo(url)
    return nil if url.blank?

    # Handle various GitHub URL formats:
    # https://github.com/owner/repo
    # https://github.com/owner/repo.git
    # git@github.com:owner/repo.git
    if url.include?("github.com")
      match = url.match(%r{github\.com[:/]([^/]+)/([^/\.]+)(?:\.git)?})
      return "#{match[1]}/#{match[2]}" if match
    end

    nil
  end

  def run_git(directory, *args)
    Open3.capture3(GIT_BIN, "-C", directory.to_s, *args)
  end

  def run_gh(*args)
    Open3.capture3(GH_BIN, *args)
  end

  def generate_pr_title
    cycle_count = cycles_since_last_pr.count
    "[Factory] #{cycle_count} automated improvements"
  end

  def generate_pr_body
    cycles = cycles_since_last_pr.order(finished_at: :asc).limit(50)

    body = <<~MD
      ## Factory Automated Improvements

      This PR contains #{cycles.count} automated improvements made by Factory agents.

      ### Cycle Summary

    MD

    cycles.each do |cycle|
      status_emoji = cycle.status == "completed" ? "✅" : "❌"
      body += "- #{status_emoji} Cycle ##{cycle.cycle_number}: #{cycle.summary.to_s.truncate(100)}\n"
    end

    body += <<~MD

      ---
      *Generated by Factory v2 on #{Time.current.strftime("%Y-%m-%d %H:%M:%S")}*
    MD

    body
  end

  def cycles_since_last_pr
    if @loop.github_last_pr_at
      @loop.factory_cycle_logs.where(status: "completed").where("finished_at > ?", @loop.github_last_pr_at)
    else
      @loop.factory_cycle_logs.where(status: "completed")
    end
  end
end
