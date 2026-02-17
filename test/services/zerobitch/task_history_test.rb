# frozen_string_literal: true

require "test_helper"

module Zerobitch
  class TaskHistoryTest < ActiveSupport::TestCase
    def setup
      @agent_id = "rex"
      @path = Rails.root.join("storage", "zerobitch", "tasks", "#{@agent_id}.json")
      @backup = File.exist?(@path) ? File.read(@path) : nil
      FileUtils.mkdir_p(@path.dirname)
      File.write(@path, "[]")
    end

    def teardown
      if @backup.nil?
        FileUtils.rm_f(@path)
      else
        File.write(@path, @backup)
      end
    end

    test "log appends and returns entry" do
      entry = TaskHistory.log(@agent_id, prompt: "check", result: "ok", duration_ms: 123, success: true)

      assert entry[:id].present?
      assert_equal "check", entry[:prompt]
      assert_equal "ok", entry[:result]
      assert_equal 123, entry[:duration_ms]
      assert_equal true, entry[:success]

      all = TaskHistory.all(@agent_id)
      assert_equal 1, all.size
    end

    test "keeps max 100 entries fifo" do
      101.times do |i|
        TaskHistory.log(@agent_id, prompt: "p#{i}", result: "r#{i}", duration_ms: i, success: true)
      end

      all = TaskHistory.all(@agent_id)
      assert_equal 100, all.size
      assert_equal "p1", all.first[:prompt]
      assert_equal "p100", all.last[:prompt]
    end

    test "clear wipes history" do
      TaskHistory.log(@agent_id, prompt: "x", result: "y", duration_ms: 1, success: false)
      assert_equal 1, TaskHistory.all(@agent_id).size

      assert TaskHistory.clear(@agent_id)
      assert_equal [], TaskHistory.all(@agent_id)
    end
  end
end
