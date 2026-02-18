# frozen_string_literal: true

require "test_helper"

class FactoryGithubServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @loop = FactoryLoop.create!(
      name: "GitHub Test Loop",
      slug: "github-test-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "minimax",
      status: "idle",
      user: @user,
      github_url: "https://github.com/wolverin0/test-repo",
      github_default_branch: "main",
      work_branch: "factory/test",
      github_pr_enabled: true,
      github_pr_batch_size: 3
    )
    @service = FactoryGithubService.new(@loop)
  end

  teardown do
    @loop&.destroy
  end

  # --- URL Parsing ---

  test "extract_owner_repo from https URL" do
    assert_equal "wolverin0/test-repo", @service.send(:extract_owner_repo, "https://github.com/wolverin0/test-repo")
  end

  test "extract_owner_repo from https URL with .git" do
    assert_equal "wolverin0/test-repo", @service.send(:extract_owner_repo, "https://github.com/wolverin0/test-repo.git")
  end

  test "extract_owner_repo from SSH URL" do
    assert_equal "wolverin0/test-repo", @service.send(:extract_owner_repo, "git@github.com:wolverin0/test-repo.git")
  end

  test "extract_owner_repo returns nil for invalid URL" do
    assert_nil @service.send(:extract_owner_repo, "not-a-github-url")
    assert_nil @service.send(:extract_owner_repo, "")
    assert_nil @service.send(:extract_owner_repo, nil)
  end

  # --- Clone ---

  test "clone! returns error when github_url is blank" do
    @loop.update!(github_url: nil)
    service = FactoryGithubService.new(@loop)

    result = service.clone!

    assert_not result.success?
    assert_includes result.message, "No github_url configured"
  end

  test "clone! returns error for invalid github_url" do
    @loop.update!(github_url: "not-a-valid-url")
    service = FactoryGithubService.new(@loop)

    result = service.clone!

    assert_not result.success?
    assert_includes result.message, "Invalid github_url"
  end

  test "clone! with stubbed git succeeds" do
    Dir.mktmpdir do |tmpdir|
      stub_workspace_root(tmpdir) do
        with_stubbed_git_clone do
          result = @service.clone!

          assert result.success?, result.message
          assert_includes result.message, "Cloned to"
          assert_equal File.join(tmpdir, @loop.slug), @loop.reload.workspace_path
        end
      end
    end
  end

  # --- Sync ---

  test "sync! returns error when github_url is blank" do
    @loop.update!(github_url: nil)
    service = FactoryGithubService.new(@loop)

    result = service.sync!

    assert_not result.success?
    assert_includes result.message, "No github_url configured"
  end

  test "sync! returns error when workspace_path is blank" do
    @loop.update!(workspace_path: nil)

    result = @service.sync!

    assert_not result.success?
    assert_includes result.message, "No workspace_path set"
  end

  test "sync! returns error when workspace does not exist" do
    @loop.update!(workspace_path: "/nonexistent/path")

    result = @service.sync!

    assert_not result.success?
    assert_includes result.message, "Workspace does not exist"
  end

  test "sync! with stubbed git succeeds" do
    Dir.mktmpdir do |tmpdir|
      @loop.update!(workspace_path: tmpdir)

      with_stubbed_git_sync do
        result = @service.sync!

        assert result.success?, result.message
        assert_includes result.message, "Synced with origin/main"
      end
    end
  end

  # --- PR Ready ---

  test "pr_ready? returns false when github_pr_enabled is false" do
    @loop.update!(github_pr_enabled: false)

    assert_not @service.pr_ready?
  end

  test "pr_ready? returns false when not enough successful cycles" do
    @loop.update!(github_pr_batch_size: 10)

    # Create 2 successful cycles (less than batch_size of 10)
    2.times do |i|
      @loop.factory_cycle_logs.create!(
        cycle_number: i + 1,
        status: "completed",
        started_at: Time.current,
        finished_at: Time.current
      )
    end

    with_stubbed_pr_exists(false) do
      assert_not @service.pr_ready?
    end
  end

  test "pr_ready? returns true when enough successful cycles" do
    @loop.update!(github_pr_batch_size: 3)

    # Create 3 successful cycles
    3.times do |i|
      @loop.factory_cycle_logs.create!(
        cycle_number: i + 1,
        status: "completed",
        started_at: Time.current,
        finished_at: Time.current
      )
    end

    with_stubbed_pr_exists(false) do
      assert @service.pr_ready?
    end
  end

  test "pr_ready? counts only cycles since last PR" do
    @loop.update!(github_pr_batch_size: 3, github_last_pr_at: 1.hour.ago)

    # Create 2 cycles after last PR (not enough)
    2.times do |i|
      @loop.factory_cycle_logs.create!(
        cycle_number: i + 1,
        status: "completed",
        started_at: Time.current,
        finished_at: Time.current
      )
    end

    # Create 5 cycles before last PR (should not count)
    5.times do |i|
      @loop.factory_cycle_logs.create!(
        cycle_number: i + 10,
        status: "completed",
        started_at: 2.hours.ago,
        finished_at: 2.hours.ago
      )
    end

    with_stubbed_pr_exists(false) do
      assert_not @service.pr_ready?
    end
  end

  # --- Model Integration ---

  test "github_repo? returns true when github_url present" do
    assert @loop.github_repo?
  end

  test "github_repo? returns false when github_url blank" do
    @loop.update!(github_url: nil)
    assert_not @loop.github_repo?
  end

  test "github_owner_repo extracts owner/repo" do
    assert_equal "wolverin0/test-repo", @loop.github_owner_repo
  end

  private

  def stub_workspace_root(tmpdir)
    original_root = FactoryGithubService::WORKSPACE_ROOT
    FactoryGithubService.send(:remove_const, :WORKSPACE_ROOT)
    FactoryGithubService.const_set(:WORKSPACE_ROOT, tmpdir)
    yield
  ensure
    FactoryGithubService.send(:remove_const, :WORKSPACE_ROOT)
    FactoryGithubService.const_set(:WORKSPACE_ROOT, original_root)
  end

  def with_stubbed_git_clone
    success_status = Struct.new(:success?).new(true)
    original_capture3 = Open3.method(:capture3)

    Open3.define_singleton_method(:capture3) do |*args|
      cmd = args.join(" ")

      if cmd.include?("clone")
        clone_dir = args.last
        FileUtils.mkdir_p(clone_dir)
        FileUtils.mkdir_p(File.join(clone_dir, ".git"))
        ["", "", success_status]
      elsif cmd.include?("fetch") || cmd.include?("checkout") || cmd.include?("pull") || cmd.include?("branch") || cmd.include?("config")
        ["", "", success_status]
      else
        ["", "", success_status]
      end
    end

    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*args, &blk| original_capture3.call(*args, &blk) }
  end

  def with_stubbed_git_sync
    success_status = Struct.new(:success?).new(true)
    original_capture3 = Open3.method(:capture3)

    Open3.define_singleton_method(:capture3) do |*args|
      ["", "", success_status]
    end

    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*args, &blk| original_capture3.call(*args, &blk) }
  end

  def with_stubbed_pr_exists(exists)
    original_capture3 = Open3.method(:capture3)
    success_status = Struct.new(:success?).new(true)

    Open3.define_singleton_method(:capture3) do |*args|
      cmd = args.join(" ")

      if cmd.include?("pr list")
        json_output = exists ? '[{"number": 1}]' : '[]'
        [json_output, "", success_status]
      else
        ["", "", success_status]
      end
    end

    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*args, &blk| original_capture3.call(*args, &blk) }
  end
end
