# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class FactoryPromotionGateServiceTest < ActiveSupport::TestCase
  test "verify! runs syntax and test checks" do
    check = FactoryPromotionGateService::Result.new(name: "ok", success: true, output: "pass")

    FactoryPromotionGateService.stub(:run_check, check) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s)

      assert result[:success]
      assert_equal "Promotion gate passed", result[:message]
      assert_equal 2, result[:checks].size
      assert_equal ["ok", "ok"], result[:checks].map { |c| c[:name] }
    end
  end

  test "verify! fails when any check fails" do
    passing = FactoryPromotionGateService::Result.new(name: "syntax_check", success: true, output: "ok")
    failing = FactoryPromotionGateService::Result.new(name: "test_command", success: false, output: "boom")

    calls = 0
    FactoryPromotionGateService.stub(:run_check, lambda { |**_kwargs|
      calls += 1
      calls == 1 ? passing : failing
    }) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s)

      assert_not result[:success]
      assert_equal "Promotion gate failed", result[:message]
      assert_equal [true, false], result[:checks].map { |c| c[:success] }
      assert_equal 2, calls
    end
  end

  test "verify! stops after first failing check by default" do
    failing = FactoryPromotionGateService::Result.new(name: "syntax_check", success: false, output: "boom")
    passing = FactoryPromotionGateService::Result.new(name: "test_command", success: true, output: "ok")

    calls = 0
    FactoryPromotionGateService.stub(:run_check, lambda { |**_kwargs|
      calls += 1
      calls == 1 ? failing : passing
    }) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s)

      assert_not result[:success]
      assert_equal 1, result[:checks].size
      assert_equal [false], result[:checks].map { |c| c[:success] }
      assert_equal 1, calls
    end
  end

  test "verify! includes e2e check when requested" do
    check = FactoryPromotionGateService::Result.new(name: "ok", success: true, output: "pass")

    FactoryPromotionGateService.stub(:run_check, check) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s, include_e2e: true)
      assert_equal 3, result[:checks].size
    end
  end

  test "verify! can continue after failures when fail_fast is false" do
    failing = FactoryPromotionGateService::Result.new(name: "syntax_check", success: false, output: "boom")

    FactoryPromotionGateService.stub(:run_check, failing) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s, include_e2e: true, fail_fast: false)
      assert_equal 3, result[:checks].size
      assert_equal [false, false, false], result[:checks].map { |c| c[:success] }
    end
  end

  test "verify! fails fast when repo_path is not a directory" do
    result = FactoryPromotionGateService.verify!("/tmp/does-not-exist")

    assert_not result[:success]
    assert_equal "Promotion gate failed", result[:message]
    assert_equal [{ name: "repo_path", success: false, output: "Repository path must point to a git repository" }], result[:checks]
  end

  test "verify! fails when directory is not a git repository" do
    Dir.mktmpdir do |tmpdir|
      result = FactoryPromotionGateService.verify!(tmpdir)

      assert_not result[:success]
      assert_equal "Promotion gate failed", result[:message]
      assert_equal [{ name: "repo_path", success: false, output: "Repository path must point to a git repository" }], result[:checks]
    end
  end

  test "check_definitions appends e2e check only when requested" do
    base = FactoryPromotionGateService.send(:check_definitions, include_e2e: false)
    with_e2e = FactoryPromotionGateService.send(:check_definitions, include_e2e: true)

    assert_equal 2, base.size
    assert_equal ["syntax_check", "test_command"], base.map { |check| check[:name] }
    assert_equal ["syntax_check", "test_command", "e2e_command"], with_e2e.map { |check| check[:name] }
  end

  test "run_check executes command in repo_path via chdir" do
    captured = nil

    Open3.stub(:capture3, lambda { |*args, **kwargs|
      captured = { args: args, kwargs: kwargs }
      ["ok", "", Struct.new(:success?).new(true)]
    }) do
      result = FactoryPromotionGateService.send(
        :run_check,
        name: "syntax_check",
        command: "bin/rails test",
        repo_path: Rails.root.to_s
      )

      assert result.success
      assert_equal ["bash", "-lc", "bin/rails test"], captured[:args]
      assert_equal Rails.root.to_s, captured[:kwargs][:chdir]
    end
  end

  test "run_check does not leak raw exception message" do
    Open3.stub(:capture3, ->(*_args) { raise StandardError, "token=super-secret" }) do
      result = FactoryPromotionGateService.send(
        :run_check,
        name: "syntax_check",
        command: "bin/rails test",
        repo_path: Rails.root.to_s
      )

      assert_not result.success
      assert_equal "StandardError: check execution failed", result.output
      assert_not_includes result.output, "super-secret"
    end
  end

  test "run_check returns timeout result when check exceeds timeout" do
    Timeout.stub(:timeout, ->(*_args) { raise Timeout::Error }) do
      result = FactoryPromotionGateService.send(
        :run_check,
        name: "test_command",
        command: "bin/rails test",
        repo_path: Rails.root.to_s
      )

      assert_not result.success
      assert_equal "Timed out after #{FactoryPromotionGateService::CHECK_TIMEOUT_SECONDS}s", result.output
    end
  end

  test "normalize_repo_path expands valid git repository directory" do
    Dir.chdir(Rails.root) do
      normalized = FactoryPromotionGateService.send(:normalize_repo_path, ".")
      assert_equal Rails.root.to_s, normalized
    end
  end

  test "normalize_repo_path accepts git worktree marker file" do
    Dir.mktmpdir do |tmpdir|
      File.write(File.join(tmpdir, ".git"), "gitdir: /tmp/fake-worktree")

      normalized = FactoryPromotionGateService.send(:normalize_repo_path, tmpdir)
      assert_equal tmpdir, normalized
    end
  end

  test "normalize_repo_path returns nil for non git subdirectory" do
    Dir.chdir(Rails.root) do
      assert_nil FactoryPromotionGateService.send(:normalize_repo_path, "app")
    end
  end
end
