# frozen_string_literal: true

require "test_helper"

class ValidationSuggestionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @service = ValidationSuggestionService.new(@user)
  end

  # --- Rule-based: empty output_files ---

  test "returns nil when output_files is empty" do
    task = create_task(output_files: [])
    assert_nil @service.generate_rule_based_suggestion(task)
  end

  test "returns nil for empty array output_files" do
    task = create_task(output_files: [])
    # output_files column has NOT NULL constraint, empty array is the "no files" case
    assert_nil @service.generate_rule_based_suggestion(task)
  end

  # --- Rule-based: test files detected ---

  test "runs specific test files when output contains _test.rb" do
    task = create_task(output_files: ["test/models/task_test.rb", "app/models/task.rb"])
    result = @service.generate_rule_based_suggestion(task)
    assert_includes result, "bin/rails test test/models/task_test.rb"
  end

  test "runs rspec when output contains _spec.rb only" do
    task = create_task(output_files: ["spec/models/task_spec.rb"])
    result = @service.generate_rule_based_suggestion(task)
    assert_includes result, "bundle exec rspec spec/models/task_spec.rb"
  end

  test "limits test files to 5" do
    files = (1..8).map { |i| "test/models/thing#{i}_test.rb" }
    task = create_task(output_files: files)
    result = @service.generate_rule_based_suggestion(task)
    assert_equal 5, result.split("bin/rails test ").last.split(" ").count
  end

  # --- Rule-based: view/CSS only ---

  test "returns nil for view-only changes" do
    task = create_task(output_files: ["app/views/tasks/show.html.erb"])
    assert_nil @service.generate_rule_based_suggestion(task)
  end

  test "returns nil for CSS-only changes" do
    task = create_task(output_files: ["app/assets/stylesheets/main.css", "app/assets/stylesheets/theme.scss"])
    assert_nil @service.generate_rule_based_suggestion(task)
  end

  test "returns nil for mixed view and CSS only" do
    task = create_task(output_files: ["app/views/tasks/show.html.erb", "app/assets/stylesheets/main.scss"])
    assert_nil @service.generate_rule_based_suggestion(task)
  end

  # --- Rule-based: JS files ---

  test "returns node -c for JS files that exist" do
    # Create a temp JS file for the test
    js_path = Rails.root.join("tmp/test_validation_file.js")
    File.write(js_path, "// test")

    task = create_task(output_files: ["tmp/test_validation_file.js"])
    result = @service.generate_rule_based_suggestion(task)
    assert_includes result, "node -c"
    assert_includes result, "tmp/test_validation_file.js"
  ensure
    File.delete(js_path) if File.exist?(js_path)
  end

  test "returns nil for JS files that do not exist on disk" do
    task = create_task(output_files: ["app/javascript/nonexistent_controller.js"])
    result = @service.generate_rule_based_suggestion(task)
    assert_nil result
  end

  # --- Rule-based: Ruby implementation files ---

  test "finds matching test for app/ Ruby files" do
    task = create_task(output_files: ["app/models/task.rb"])
    result = @service.generate_rule_based_suggestion(task)
    # test/models/task_test.rb should exist in the project
    assert_match(/bin\/rails test/, result)
  end

  test "falls back to bin/rails test when no matching test found" do
    task = create_task(output_files: ["app/models/nonexistent_thing.rb"])
    result = @service.generate_rule_based_suggestion(task)
    assert_equal "bin/rails test", result
  end

  # --- Rule-based: Python files ---

  test "returns pytest for Python files" do
    task = create_task(output_files: ["scripts/analyze.py"])
    result = @service.generate_rule_based_suggestion(task)
    assert_equal "python -m pytest", result
  end

  # --- Rule-based: unknown file types ---

  test "returns nil for unknown file types" do
    task = create_task(output_files: ["README.md", "CHANGELOG.txt"])
    assert_nil @service.generate_rule_based_suggestion(task)
  end

  # --- Class method ---

  test "class method generate_rule_based works without user" do
    task = create_task(output_files: ["app/models/task.rb"])
    result = ValidationSuggestionService.generate_rule_based(task)
    assert_match(/bin\/rails test/, result)
  end

  # --- Instance generate_suggestion ---

  test "generate_suggestion falls back to rule-based when rule_based_only" do
    task = create_task(output_files: ["scripts/analyze.py"])
    result = @service.generate_suggestion(task, rule_based_only: true)
    assert_equal "python -m pytest", result
  end

  test "generate_suggestion falls back to rule-based when AI not configured" do
    service = ValidationSuggestionService.new(nil)
    task = create_task(output_files: ["scripts/analyze.py"])
    result = service.generate_suggestion(task)
    assert_equal "python -m pytest", result
  end

  private

  def create_task(output_files:)
    @board.tasks.create!(
      name: "Test task",
      user: @user,
      status: :in_review,
      output_files: output_files
    )
  end
end
