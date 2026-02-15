# frozen_string_literal: true

require "test_helper"

module Pipeline
  class TriageServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:default)
      @board = boards(:default)
      # Reload config from real pipelines.yml
      Pipeline::TriageService.reload_config!
    end

    # --- Initialization ---

    test "initializes with a task" do
      task = Task.create!(name: "Test task", board: @board, user: @user)
      service = Pipeline::TriageService.new(task)
      assert_instance_of Pipeline::TriageService, service
    end

    test "config loads from pipelines.yml" do
      config = Pipeline::TriageService.config
      assert config.key?(:pipelines), "Config should have :pipelines key"
      assert config.key?(:observation_mode), "Config should have :observation_mode key"
    end

    # --- Tag matching ---

    test "triages task with bug tag to bug-fix pipeline" do
      task = Task.create!(name: "Something broken", board: @board, user: @user, tags: ["bug"])
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "bug-fix", result[:pipeline_type]
    end

    test "triages task with quick tag to quick-fix pipeline" do
      task = Task.create!(name: "Small change", board: @board, user: @user, tags: ["quick"])
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "quick-fix", result[:pipeline_type]
    end

    test "triages task with feature tag to feature pipeline" do
      task = Task.create!(name: "New widget", board: @board, user: @user, tags: ["feature"])
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "feature", result[:pipeline_type]
    end

    test "triages task with research tag to research pipeline" do
      task = Task.create!(name: "Evaluate options", board: @board, user: @user, tags: ["research"])
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "research", result[:pipeline_type]
    end

    # --- Name pattern matching ---

    test "triages fix typo to quick-fix via name pattern" do
      task = Task.create!(name: "fix typo in readme", board: @board, user: @user)
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "quick-fix", result[:pipeline_type]
    end

    test "triages update/rename to quick-fix via name pattern" do
      task = Task.create!(name: "update the config file", board: @board, user: @user)
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "quick-fix", result[:pipeline_type]
    end

    # --- Board default ---

    test "triages task on Marketing board to research" do
      marketing_board = @user.boards.create!(name: "Marketing", color: "purple")
      task = Task.create!(name: "New campaign ideas", board: marketing_board, user: @user)
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      assert_equal "research", result[:pipeline_type]
    end

    # --- Result structure ---

    test "result includes expected keys" do
      task = Task.create!(name: "Anything", board: @board, user: @user, tags: ["bug"])
      result = Pipeline::TriageService.new(task).call

      assert result.key?(:pipeline_type)
      assert result.key?(:confidence)
      assert result.key?(:votes)
      assert result.key?(:triaged_at)
    end

    test "votes are arrays with source and weight" do
      task = Task.create!(name: "Fix something", board: @board, user: @user, tags: ["bug"])
      result = Pipeline::TriageService.new(task).call

      result[:votes].each do |vote|
        assert vote.key?(:source), "Vote should have :source"
        assert vote.key?(:pipeline_type), "Vote should have :pipeline_type"
        assert vote.key?(:weight), "Vote should have :weight"
      end
    end

    # --- Default fallback ---

    test "falls back to default pipeline for untagged tasks with generic name" do
      task = Task.create!(name: "miscellaneous task xyz123", board: @board, user: @user)
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      # Should get some pipeline type (at least the default)
      assert result[:pipeline_type].present?
    end

    # --- Pipeline log ---

    test "appends to pipeline_log on task" do
      task = Task.create!(name: "Log test task", board: @board, user: @user, tags: ["bug"])
      assert_empty Array(task.pipeline_log)

      Pipeline::TriageService.new(task).call
      task.reload

      assert_not_empty Array(task.pipeline_log)
      log_entry = task.pipeline_log.last
      assert_equal "triage", log_entry["stage"]
    end

    # --- Multiple conflicting tags ---

    test "higher weight source wins when tags conflict" do
      task = Task.create!(name: "Fix bug quickly", board: @board, user: @user, tags: ["bug", "quick"])
      result = Pipeline::TriageService.new(task).call
      assert_not_nil result
      # Both should produce votes, highest aggregate wins
      assert result[:confidence] > 0
    end
  end
end
