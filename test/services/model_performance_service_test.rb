# frozen_string_literal: true

require "test_helper"

class ModelPerformanceServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:default)
  end

  # --- Initialization ---

  test "initializes with user and default period" do
    service = ModelPerformanceService.new(@user)
    assert_instance_of ModelPerformanceService, service
  end

  test "initializes with custom period" do
    service = ModelPerformanceService.new(@user, period: 7.days)
    assert_instance_of ModelPerformanceService, service
  end

  # --- Report structure ---

  test "report returns expected keys" do
    report = ModelPerformanceService.new(@user).report
    assert_includes report.keys, :period_days
    assert_includes report.keys, :total_tasks
    assert_includes report.keys, :by_model
    assert_includes report.keys, :by_task_type
    assert_includes report.keys, :recommendations
    assert_includes report.keys, :generated_at
  end

  test "report period_days is correct" do
    report = ModelPerformanceService.new(@user, period: 7.days).report
    assert_equal 7, report[:period_days]
  end

  test "report total_tasks is non-negative" do
    report = ModelPerformanceService.new(@user).report
    assert report[:total_tasks] >= 0
  end

  test "report by_model is a hash" do
    report = ModelPerformanceService.new(@user).report
    assert_kind_of Hash, report[:by_model]
  end

  test "report by_task_type is a hash" do
    report = ModelPerformanceService.new(@user).report
    assert_kind_of Hash, report[:by_task_type]
  end

  test "report recommendations is an array" do
    report = ModelPerformanceService.new(@user).report
    assert_kind_of Array, report[:recommendations]
  end

  test "report generated_at is ISO8601" do
    report = ModelPerformanceService.new(@user).report
    assert_nothing_raised { Time.parse(report[:generated_at]) }
  end

  # --- Summary structure ---

  test "summary returns expected keys" do
    summary = ModelPerformanceService.new(@user).summary
    assert_includes summary.keys, :total_tasks
    assert_includes summary.keys, :models_used
    assert_includes summary.keys, :best_model
    assert_includes summary.keys, :best_success_rate
    assert_includes summary.keys, :total_cost
  end

  test "summary total_tasks is non-negative" do
    summary = ModelPerformanceService.new(@user).summary
    assert summary[:total_tasks] >= 0
  end

  test "summary models_used is non-negative" do
    summary = ModelPerformanceService.new(@user).summary
    assert summary[:models_used] >= 0
  end

  test "summary total_cost is a number" do
    summary = ModelPerformanceService.new(@user).summary
    assert_kind_of Numeric, summary[:total_cost]
  end

  # --- normalize_model (tested via send) ---

  test "normalize_model maps opus variants" do
    service = ModelPerformanceService.new(@user)
    assert_equal "opus", service.send(:normalize_model, "anthropic/claude-opus-4-6")
    assert_equal "opus", service.send(:normalize_model, "opus")
    assert_equal "opus", service.send(:normalize_model, "Claude Opus")
  end

  test "normalize_model maps sonnet variants" do
    service = ModelPerformanceService.new(@user)
    assert_equal "sonnet", service.send(:normalize_model, "anthropic/claude-sonnet-4")
    assert_equal "sonnet", service.send(:normalize_model, "sonnet")
  end

  test "normalize_model maps codex" do
    service = ModelPerformanceService.new(@user)
    assert_equal "codex", service.send(:normalize_model, "openai-codex/gpt-5.3-codex")
    assert_equal "codex", service.send(:normalize_model, "codex")
  end

  test "normalize_model maps gemini" do
    service = ModelPerformanceService.new(@user)
    assert_equal "gemini", service.send(:normalize_model, "google-gemini-cli/gemini-2.5-pro")
    assert_equal "gemini", service.send(:normalize_model, "gemini")
  end

  test "normalize_model maps glm" do
    service = ModelPerformanceService.new(@user)
    assert_equal "glm", service.send(:normalize_model, "zai/glm-4.7")
    assert_equal "glm", service.send(:normalize_model, "glm")
  end

  test "normalize_model returns last segment for unknown models" do
    service = ModelPerformanceService.new(@user)
    assert_equal "mistral-medium-latest", service.send(:normalize_model, "mistral/mistral-medium-latest")
  end

  test "normalize_model returns nil for blank" do
    service = ModelPerformanceService.new(@user)
    assert_nil service.send(:normalize_model, "")
    assert_nil service.send(:normalize_model, nil)
  end

  # --- success_rate ---

  test "success_rate returns 0 for empty array" do
    service = ModelPerformanceService.new(@user)
    assert_equal 0.0, service.send(:success_rate, [])
  end

  # --- avg_completion_time ---

  test "avg_completion_time returns nil for empty array" do
    service = ModelPerformanceService.new(@user)
    assert_nil service.send(:avg_completion_time, [])
  end

  # --- Recommendation severity levels ---

  test "recommendations have valid severity values" do
    report = ModelPerformanceService.new(@user).report
    report[:recommendations].each do |rec|
      assert_includes %w[high medium low], rec[:severity], "Invalid severity: #{rec[:severity]}"
      assert rec[:message].present?, "Recommendation must have a message"
      assert rec[:type].present?, "Recommendation must have a type"
    end
  end
end
