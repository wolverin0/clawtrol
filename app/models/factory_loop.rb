# frozen_string_literal: true

require "cgi"
require "fileutils"
require "open3"
require "pathname"
require "uri"

class FactoryLoop < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :factory_loops
  has_many :factory_cycle_logs, dependent: :destroy, inverse_of: :factory_loop, counter_cache: :cycle_count
  has_many :factory_loop_agents, dependent: :destroy, inverse_of: :factory_loop
  has_many :factory_agents, through: :factory_loop_agents
  has_many :factory_agent_runs, dependent: :destroy, inverse_of: :factory_loop

  STATUSES = %w[idle playing paused stopped error error_paused].freeze

  validates :name, :slug, :interval_ms, :model, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :interval_ms, numericality: { only_integer: true, greater_than: 0 }
  validates :idle_policy, inclusion: { in: %w[pause maintenance full_auto] }, allow_nil: true
  validates :confidence_threshold, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validates :max_findings_per_run, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_session_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:name) }
  scope :by_status, ->(status) { where(status:) if status.present? }
  scope :playing, -> { where(status: "playing") }
  scope :with_idle_policy, ->(policy) { where(idle_policy: policy) }

  # Status query methods
  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  before_validation :normalize_slug
  after_commit :sync_engine, if: :saved_change_to_status?

  def play!
    update!(status: "playing", last_cycle_at: nil, consecutive_failures: 0)
  end

  def pause!
    update!(status: "paused")
  end

  def stop!
    update!(status: "stopped", state: {})
  end

  def as_json(options = {})
    super(options.merge(include: { factory_cycle_logs: { only: [ :id, :cycle_number, :status, :started_at, :finished_at, :duration_ms, :summary ] } }))
  end

  def enabled_agents
    factory_agents.joins(:factory_loop_agents).merge(FactoryLoopAgent.enabled)
  end

  def setup_workspace!
    raise ArgumentError, "workspace_path is required" if workspace_path.blank?

    ensure_work_branch!
    ensure_worktree!
    configure_workspace_hooks!
    setup_db_sandbox! if db_url_override.present?

    true
  end

  def teardown_workspace!
    remove_worktree!
    teardown_db_sandbox! if db_url_override.present?

    true
  end

  private

  GIT_BIN = "/usr/bin/git"

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end

  def git_repo_path
    configured_repo = config.is_a?(Hash) ? config["git_repo_path"] : nil
    Pathname.new((configured_repo.presence || Rails.root).to_s)
  end

  def workspace_pathname
    Pathname.new(workspace_path)
  end

  def effective_work_branch
    work_branch.presence || "factory/auto"
  end

  def protected_branch_list
    Array(protected_branches).presence || %w[main master]
  end

  def ensure_work_branch!
    branch_name = effective_work_branch
    stdout, = run_git!(git_repo_path.to_s, "branch", "--list", branch_name)
    return if stdout.to_s.strip.present?

    Rails.logger.info("[FactoryLoop##{id}] Creating work branch #{branch_name}")
    run_git!(git_repo_path.to_s, "branch", branch_name)
  end

  def ensure_worktree!
    return if worktree_exists?

    FileUtils.mkdir_p(workspace_pathname.dirname)
    Rails.logger.info("[FactoryLoop##{id}] Adding worktree at #{workspace_path}")
    run_git!(git_repo_path.to_s, "worktree", "add", workspace_path, effective_work_branch)
  end

  def worktree_exists?
    return false if workspace_path.blank?
    return true if File.exist?(File.join(workspace_path, ".git"))

    stdout, = run_git!(git_repo_path.to_s, "worktree", "list", "--porcelain")
    listed_paths = stdout.lines.filter_map do |line|
      next unless line.start_with?("worktree ")

      line.delete_prefix("worktree ").strip
    end

    listed_paths.include?(workspace_path)
  rescue StandardError
    false
  end

  def configure_workspace_hooks!
    hooks_dir = File.join(workspace_path, ".factory-hooks")
    FileUtils.mkdir_p(hooks_dir)

    hook_path = File.join(hooks_dir, "pre-commit")
    File.write(hook_path, pre_commit_hook_script)
    FileUtils.chmod(0o755, hook_path)

    run_git!(workspace_path, "config", "core.hooksPath", ".factory-hooks")
  end

  def pre_commit_hook_script
    protected = protected_branch_list.map { |branch| branch.to_s.inspect }.join(" ")

    <<~BASH
      #!/usr/bin/env bash
      set -euo pipefail

      current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
      protected_branches=(#{protected})

      for protected_branch in "${protected_branches[@]}"; do
        if [ "$current_branch" = "$protected_branch" ]; then
          echo "✋ Commits to protected branch '$current_branch' are blocked by FactoryLoop"
          exit 1
        fi
      done
    BASH
  end

  def setup_db_sandbox!
    db_info = parsed_db_override
    return if db_info.nil?

    with_admin_connection(db_info) do |admin_conn|
      create_database_unless_exists!(admin_conn, db_info[:database])
      create_user_unless_exists!(admin_conn, db_info[:username], db_info[:password])
    end

    with_database_connection(db_info) do |sandbox_conn|
      grant_restricted_privileges!(sandbox_conn, db_info[:username])
    end
  end

  def teardown_db_sandbox!
    db_info = parsed_db_override
    return if db_info.nil?

    with_admin_connection(db_info) do |admin_conn|
      admin_conn.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = #{admin_conn.quote(db_info[:database])} AND pid <> pg_backend_pid()")
      admin_conn.execute("DROP DATABASE IF EXISTS #{quote_ident(db_info[:database])}")
    end
  end

  def parsed_db_override
    uri = URI.parse(db_url_override)
    return nil unless %w[postgres postgresql].include?(uri.scheme)

    {
      host: uri.host,
      port: uri.port,
      database: uri.path.to_s.delete_prefix("/"),
      username: CGI.unescape(uri.user.to_s),
      password: CGI.unescape(uri.password.to_s)
    }
  rescue URI::InvalidURIError
    nil
  end

  def with_admin_connection(db_info)
    config_hash = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup.symbolize_keys
    config_hash[:host] = db_info[:host] if db_info[:host].present?
    config_hash[:port] = db_info[:port] if db_info[:port].present?
    config_hash[:database] = "postgres"

    with_temporary_connection(config_hash) { |conn| yield conn }
  end

  def with_database_connection(db_info)
    config_hash = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup.symbolize_keys
    config_hash[:host] = db_info[:host] if db_info[:host].present?
    config_hash[:port] = db_info[:port] if db_info[:port].present?
    config_hash[:database] = db_info[:database]

    with_temporary_connection(config_hash) { |conn| yield conn }
  end

  def with_temporary_connection(config_hash)
    klass = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
    end

    klass.establish_connection(config_hash)
    yield klass.connection
  ensure
    klass.connection_pool.disconnect! if klass&.connection_pool
  end

  def create_database_unless_exists!(conn, database_name)
    exists = conn.select_value("SELECT 1 FROM pg_database WHERE datname = #{conn.quote(database_name)}")
    return if exists.present?

    conn.execute("CREATE DATABASE #{quote_ident(database_name)}")
  end

  def create_user_unless_exists!(conn, username, password)
    exists = conn.select_value("SELECT 1 FROM pg_roles WHERE rolname = #{conn.quote(username)}")
    conn.execute("CREATE USER #{quote_ident(username)} WITH PASSWORD #{conn.quote(password)}") unless exists.present?
  end

  def grant_restricted_privileges!(conn, username)
    quoted_user = quote_ident(username)

    conn.execute("GRANT CONNECT ON DATABASE #{quote_ident(conn.current_database)} TO #{quoted_user}")
    conn.execute("GRANT USAGE ON SCHEMA public TO #{quoted_user}")
    conn.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{quoted_user}")
    conn.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO #{quoted_user}")
  end

  def quote_ident(value)
    %("#{value.to_s.gsub('"', '""')}")
  end

  def remove_worktree!
    return if workspace_path.blank?

    run_git(git_repo_path.to_s, "worktree", "remove", workspace_path, "--force")
  end

  def run_git!(directory, *args)
    stdout, stderr, status = Open3.capture3(GIT_BIN, "-C", directory.to_s, *args)
    return [ stdout, stderr ] if status.success?

    raise "git #{args.join(' ')} failed: #{stderr.presence || stdout}"
  end

  def run_git(directory, *args)
    Open3.capture3(GIT_BIN, "-C", directory.to_s, *args)
  end

  def sync_engine
    if status == "playing"
      FactoryEngineService.new.start_loop(self)
    elsif %w[paused stopped idle error error_paused].include?(status)
      FactoryEngineService.new.stop_loop(self)
    end
  end
end
