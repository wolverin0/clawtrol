# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "test_helper"

class FactoryLoopTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
  end

  def build_loop(attrs = {})
    FactoryLoop.new({
      name: "Test Loop",
      slug: "test-loop-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "minimax",
      status: "idle",
      user: @user,
      openclaw_cron_id: "cron-#{SecureRandom.hex(4)}"
    }.merge(attrs))
  end

  # --- Validations ---
  test "valid with all required fields" do
    fl = build_loop
    assert fl.valid?, fl.errors.full_messages.join(", ")
  end

  test "requires name" do
    fl = build_loop(name: nil)
    assert_not fl.valid?
    assert_includes fl.errors[:name], "can't be blank"
  end

  test "requires slug" do
    fl = build_loop(slug: nil)
    assert_not fl.valid?
  end

  test "requires interval_ms" do
    fl = build_loop(interval_ms: nil)
    assert_not fl.valid?
  end

  test "requires model" do
    fl = build_loop(model: nil)
    assert_not fl.valid?
  end

  test "interval_ms must be positive integer" do
    fl = build_loop(interval_ms: 0)
    assert_not fl.valid?
  end

  test "slug must be unique" do
    build_loop(slug: "unique-slug").save!
    fl2 = build_loop(slug: "unique-slug")
    assert_not fl2.valid?
    assert_includes fl2.errors[:slug], "has already been taken"
  end

  test "slug is normalized to kebab-case before validation" do
    fl = build_loop(slug: "INVALID SLUG!")
    fl.valid?  # triggers before_validation normalization
    assert_equal "invalid-slug", fl.slug
  end

  test "slug accepts valid kebab-case" do
    fl = build_loop(slug: "my-loop-123")
    assert fl.valid?, fl.errors.full_messages.join(", ")
  end

  test "status must be in STATUSES" do
    fl = build_loop(status: "dancing")
    assert_not fl.valid?
    assert_includes fl.errors[:status], "is not included in the list"
  end

  # --- Status query methods ---
  test "idle? returns true when idle" do
    fl = build_loop(status: "idle")
    assert fl.idle?
    assert_not fl.playing?
  end

  test "playing? returns true when playing" do
    fl = build_loop(status: "playing")
    assert fl.playing?
    assert_not fl.idle?
  end

  test "error? returns true when error" do
    fl = build_loop(status: "error")
    assert fl.error?
  end

  # --- Scopes ---
  test "ordered scope orders by name" do
    fl1 = build_loop(name: "Bravo", slug: "bravo-#{SecureRandom.hex(4)}")
    fl1.save!
    fl2 = build_loop(name: "Alpha", slug: "alpha-#{SecureRandom.hex(4)}")
    fl2.save!
    ordered = FactoryLoop.ordered.where(id: [fl1.id, fl2.id])
    assert_equal "Alpha", ordered.first.name
  end

  test "playing scope" do
    fl1 = build_loop(status: "playing", slug: "play-#{SecureRandom.hex(4)}")
    fl1.save!
    fl2 = build_loop(status: "idle", slug: "idle-#{SecureRandom.hex(4)}")
    fl2.save!
    assert_includes FactoryLoop.playing, fl1
    assert_not_includes FactoryLoop.playing, fl2
  end

  # --- Slug normalization ---
  test "normalize_slug parameterizes on save" do
    fl = build_loop(slug: "My Loop Name")
    fl.valid?
    assert_equal "my-loop-name", fl.slug
  end

  # --- Associations ---
  test "has_many factory_cycle_logs" do
    fl = build_loop
    fl.save!
    log = fl.factory_cycle_logs.create!(
      cycle_number: 1,
      started_at: Time.current,
      status: "completed"
    )
    assert_equal 1, fl.factory_cycle_logs.count
    fl.destroy
    assert_equal 0, FactoryCycleLog.where(id: log.id).count
  end

  test "setup_workspace! creates worktree directory" do
    Dir.mktmpdir do |tmpdir|
      workspace = File.join(tmpdir, "worktree")
      loop = build_loop(workspace_path: workspace, work_branch: "factory/test", config: { "git_repo_path" => tmpdir })

      with_stubbed_git(workspace) do
        loop.setup_workspace!
      end

      assert File.directory?(workspace)
    end
  end

  test "setup_workspace! creates work_branch if missing" do
    Dir.mktmpdir do |tmpdir|
      workspace = File.join(tmpdir, "worktree")
      loop = build_loop(workspace_path: workspace, work_branch: "factory/new-branch", config: { "git_repo_path" => tmpdir })
      commands = []

      with_stubbed_git(workspace, commands:) do
        loop.setup_workspace!
      end

      assert commands.any? { |cmd| cmd.include?("branch --list factory/new-branch") }
      assert commands.any? { |cmd| cmd.include?("branch factory/new-branch") }
    end
  end

  test "setup_workspace! writes pre-commit hook" do
    Dir.mktmpdir do |tmpdir|
      workspace = File.join(tmpdir, "worktree")
      loop = build_loop(
        workspace_path: workspace,
        work_branch: "factory/test",
        protected_branches: %w[main release],
        config: { "git_repo_path" => tmpdir }
      )

      with_stubbed_git(workspace) do
        loop.setup_workspace!
      end

      hook_path = File.join(workspace, ".factory-hooks", "pre-commit")
      assert File.exist?(hook_path)
      hook = File.read(hook_path)
      assert_includes hook, "git symbolic-ref --short HEAD"
      assert_includes hook, "main"
      assert_includes hook, "release"
    end
  end

  test "setup_workspace! is idempotent" do
    Dir.mktmpdir do |tmpdir|
      workspace = File.join(tmpdir, "worktree")
      loop = build_loop(workspace_path: workspace, work_branch: "factory/test", config: { "git_repo_path" => tmpdir })

      with_stubbed_git(workspace) do
        loop.setup_workspace!
        loop.setup_workspace!
      end

      assert File.exist?(File.join(workspace, ".git"))
    end
  end

  test "setup_workspace! raises if workspace_path is blank" do
    loop = build_loop(workspace_path: nil)

    assert_raises(ArgumentError) { loop.setup_workspace! }
  end

  test "teardown_workspace! removes worktree" do
    Dir.mktmpdir do |tmpdir|
      workspace = File.join(tmpdir, "worktree")
      loop = build_loop(workspace_path: workspace, work_branch: "factory/test", config: { "git_repo_path" => tmpdir })

      with_stubbed_git(workspace) do
        loop.setup_workspace!
        assert File.exist?(File.join(workspace, ".git"))

        loop.teardown_workspace!
      end

      assert_not File.exist?(workspace)
    end
  end

  test "setup_workspace! executes db sandbox SQL when db_url_override is present" do
    loop = build_loop(
      workspace_path: "/tmp/factory-db-sandbox",
      db_url_override: "postgres://sandbox_user:sandbox_pass@localhost:5432/sandbox_db"
    )
    admin_sql = []
    sandbox_sql = []
    admin_conn = fake_connection(admin_sql)
    sandbox_conn = fake_connection(sandbox_sql, database: "sandbox_db")

    with_replaced_singleton_method(loop, :ensure_work_branch!, -> { true }) do
      with_replaced_singleton_method(loop, :ensure_worktree!, -> { true }) do
        with_replaced_singleton_method(loop, :configure_workspace_hooks!, -> { true }) do
          with_replaced_singleton_method(loop, :with_admin_connection, ->(_db_info, &blk) { blk.call(admin_conn) }) do
            with_replaced_singleton_method(loop, :with_database_connection, ->(_db_info, &blk) { blk.call(sandbox_conn) }) do
              loop.setup_workspace!
            end
          end
        end
      end
    end

    assert admin_sql.any? { |sql| sql.include?("CREATE DATABASE") }
    assert admin_sql.any? { |sql| sql.include?("CREATE USER") }
    assert sandbox_sql.any? { |sql| sql.include?("GRANT SELECT, INSERT, UPDATE, DELETE") }
  end

  private

  def with_stubbed_git(workspace_path, commands: [])
    success = Struct.new(:success?).new(true)
    original_capture3 = Open3.method(:capture3)

    Open3.define_singleton_method(:capture3) do |*args|
      cmd = args.join(" ")
      commands << cmd

      if cmd.include?(" branch --list ")
        [ "", "", success ]
      elsif cmd.include?(" worktree add ")
        FileUtils.mkdir_p(workspace_path)
        File.write(File.join(workspace_path, ".git"), "gitdir: /tmp/fake")
        [ "", "", success ]
      elsif cmd.include?(" worktree list --porcelain")
        [ "", "", success ]
      elsif cmd.include?(" worktree remove ")
        FileUtils.rm_rf(workspace_path)
        [ "", "", success ]
      else
        [ "", "", success ]
      end
    end

    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*args, &blk| original_capture3.call(*args, &blk) }
  end

  def fake_connection(executed_sql, database: "postgres")
    Class.new do
      define_method(:initialize) do |sqls, db|
        @sqls = sqls
        @db = db
      end

      define_method(:select_value) { |_sql| nil }
      define_method(:quote) { |value| "'#{value}'" }
      define_method(:execute) { |sql| @sqls << sql }
      define_method(:current_database) { @db }
    end.new(executed_sql, database)
  end

  def with_replaced_singleton_method(object, method_name, replacement)
    singleton = object.singleton_class
    had_method = singleton.method_defined?(method_name)
    original_method = singleton.instance_method(method_name) if had_method

    singleton.define_method(method_name, &replacement)
    yield
  ensure
    if had_method
      singleton.define_method(method_name, original_method)
    else
      singleton.remove_method(method_name)
    end
  end
end
