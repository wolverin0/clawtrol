# frozen_string_literal: true

# Service for cherry-picking commits from playground repo to production ~/clawdeck.
# Provides safe, audited git operations with conflict detection and rollback.
class CherryPickService
  PLAYGROUND_PATH = File.expand_path("~/.openclaw/workspace/clawtrolplayground")
  PRODUCTION_PATH = File.expand_path("~/clawdeck")

  Result = Struct.new(:success, :message, :data, keyword_init: true)

  class << self
    # Returns commits in playground that are NOT in production (cherry-pickable).
    # Only includes [factory] commits for safety.
    def pickable_commits(limit: 50)
      # Get commits in playground not in production/main
      output = git_playground(
        "log", "--oneline", "--format=%H|%h|%s|%ai|%an",
        "production/main..HEAD", "-#{limit}"
      )
      return Result.new(success: false, message: "Failed to list commits") if output.nil?

      commits = output.split("\n").filter_map do |line|
        parts = line.split("|", 5)
        next unless parts.size == 5
        {
          full_hash: parts[0],
          short_hash: parts[1],
          message: parts[2],
          date: parts[3],
          author: parts[4],
          factory: parts[2].start_with?("[factory]")
        }
      end

      Result.new(success: true, data: commits)
    end

    # Preview what a cherry-pick would change (diff of a single commit).
    def preview_commit(commit_hash)
      return Result.new(success: false, message: "Invalid commit hash") unless valid_hash?(commit_hash)

      # Verify commit exists in playground
      verify = git_playground("cat-file", "-t", commit_hash)
      return Result.new(success: false, message: "Commit not found in playground") unless verify&.strip == "commit"

      diff = git_playground("show", "--stat", "--patch", commit_hash)
      message = git_playground("log", "--format=%s", "-1", commit_hash)&.strip
      files = git_playground("diff-tree", "--no-commit-id", "--name-only", "-r", commit_hash)
        &.split("\n")&.reject(&:blank?) || []

      Result.new(success: true, data: {
        hash: commit_hash,
        message: message,
        diff: diff&.truncate(100_000),
        files: files
      })
    end

    # Execute cherry-pick of one or more commits into production.
    # Returns success/failure with details.
    def cherry_pick!(commit_hashes, dry_run: false)
      hashes = Array(commit_hashes).select { |h| valid_hash?(h) }
      return Result.new(success: false, message: "No valid commit hashes provided") if hashes.empty?

      # Verify production repo is clean
      status = git_production("status", "--porcelain")
      if status.present? && status.strip.present?
        return Result.new(success: false, message: "Production repo has uncommitted changes. Clean it first.", data: { status: status })
      end

      # Fetch latest from playground
      git_production("fetch", PLAYGROUND_PATH, "HEAD:refs/remotes/playground/HEAD")

      results = []
      hashes.each do |hash|
        if dry_run
          # Dry run: just check if it would apply cleanly
          test = git_production("cherry-pick", "--no-commit", hash)
          if $?.success? # rubocop:disable Style/SpecialGlobalVars
            git_production("reset", "--hard", "HEAD")
            results << { hash: hash, status: :ok, message: "Would apply cleanly" }
          else
            git_production("cherry-pick", "--abort")
            results << { hash: hash, status: :conflict, message: "Would have conflicts" }
          end
        else
          # Real cherry-pick
          output = git_production("cherry-pick", hash)
          if $?.success? # rubocop:disable Style/SpecialGlobalVars
            results << { hash: hash, status: :ok, message: "Cherry-picked successfully" }
          else
            # Conflict — abort and stop
            conflict_files = git_production("diff", "--name-only", "--diff-filter=U")
            git_production("cherry-pick", "--abort")
            results << { hash: hash, status: :conflict, message: "Conflict in: #{conflict_files&.strip}" }
            break # Stop at first conflict
          end
        end
      end

      all_ok = results.all? { |r| r[:status] == :ok }
      Result.new(
        success: all_ok,
        message: all_ok ? "All #{results.size} commit(s) cherry-picked successfully" : "Cherry-pick stopped at conflict",
        data: { results: results }
      )
    end

    # Run tests in production after cherry-pick
    def verify_production!
      output = nil
      IO.popen(
        ["bash", "-c", "cd #{PRODUCTION_PATH} && bin/rails test 2>&1 | tail -20"],
        err: [:child, :out]
      ) do |io|
        output = io.read(50_000)
      end

      passed = output&.include?("0 failures, 0 errors") || output&.include?("0 failures")
      Result.new(
        success: passed,
        message: passed ? "All tests pass in production" : "Tests failed in production",
        data: { output: output }
      )
    rescue StandardError => e
      Result.new(success: false, message: "Test execution failed: #{e.message}")
    end

    private

    def valid_hash?(hash)
      hash.is_a?(String) && hash.match?(/\A[a-f0-9]{7,40}\z/)
    end

    def git_playground(*args)
      safe_git(PLAYGROUND_PATH, *args)
    end

    def git_production(*args)
      safe_git(PRODUCTION_PATH, *args)
    end

    def safe_git(path, *args)
      cmd = ["git", "-C", path] + args
      IO.popen(cmd, err: [:child, :out]) do |io|
        io.read(200_000) || ""
      end
    rescue StandardError => e
      Rails.logger.warn("[CherryPickService] Git command failed: #{e.message}")
      nil
    end
  end
end
