# frozen_string_literal: true

# AgentActionRecorder parses an agent's transcript (JSONL) and extracts
# structured tool-call actions, auto-generated assertions, and test code
# for regression testing of agent behavior.
#
# Usage:
#   recorder = AgentActionRecorder.new(task)
#   result = recorder.record!
#   result.recording  # => AgentTestRecording (persisted)
#   result.error      # => nil or error message
#
class AgentActionRecorder
  FILE_TOOLS = %w[Write write Edit edit].freeze
  READ_TOOLS = %w[Read read].freeze
  EXEC_TOOLS = %w[exec Exec].freeze
  MAX_ACTIONS = 200
  MAX_SUMMARY_SIZE = 500

  Result = Struct.new(:recording, :error, keyword_init: true)

  def initialize(task)
    @task = task
  end

  def record!
    session_id = @task.agent_session_id
    return Result.new(recording: nil, error: "No agent session found") unless session_id.present?

    transcript_path = TranscriptParser.transcript_path(session_id)
    return Result.new(recording: nil, error: "Transcript not found for session #{session_id}") unless transcript_path

    actions = parse_actions(transcript_path)
    assertions = generate_assertions(actions)
    metadata = build_metadata(actions, transcript_path)
    test_code = generate_test_code(actions, assertions)

    recording = @task.agent_test_recordings.create!(
      user: @task.user,
      session_id: session_id,
      actions: actions.first(MAX_ACTIONS),
      assertions: assertions,
      metadata: metadata,
      generated_test_code: test_code,
      status: "recorded"
    )

    Result.new(recording: recording, error: nil)
  rescue StandardError => e
    Result.new(recording: nil, error: "#{e.class}: #{e.message}")
  end

  private

  def parse_actions(transcript_path)
    actions = []
    File.foreach(transcript_path).with_index do |line, idx|
      break if idx > 5000 # safety limit

      parsed = JSON.parse(line) rescue next
      next unless parsed["type"] == "tool_use" || parsed["role"] == "assistant"

      tool_name = parsed.dig("content", "name") || parsed["tool"] || parsed["name"]
      next unless tool_name

      input = parsed.dig("content", "input") || parsed["input"] || {}

      actions << {
        "index" => actions.size,
        "tool" => tool_name,
        "input_summary" => summarize_input(tool_name, input),
        "timestamp" => parsed["timestamp"]
      }

      break if actions.size >= MAX_ACTIONS
    end
    actions
  end

  def summarize_input(tool_name, input)
    input = input.is_a?(Hash) ? input : {}

    case tool_name.downcase
    when "write"
      file_path = input["file_path"] || input["path"]
      content = input["content"].to_s
      {
        "file_path" => file_path,
        "operation" => "write",
        "content_preview" => content.truncate(MAX_SUMMARY_SIZE),
        "content_lines" => content.lines.count
      }
    when "edit"
      file_path = input["file_path"] || input["path"]
      {
        "file_path" => file_path,
        "operation" => "edit",
        "old_text_preview" => input["old_string"]&.truncate(MAX_SUMMARY_SIZE) || input["oldText"]&.truncate(MAX_SUMMARY_SIZE),
        "new_text_preview" => input["new_string"]&.truncate(MAX_SUMMARY_SIZE) || input["newText"]&.truncate(MAX_SUMMARY_SIZE)
      }
    when "read"
      {
        "file_path" => input["file_path"] || input["path"],
        "offset" => input["offset"],
        "limit" => input["limit"]
      }
    when "exec"
      {
        "command" => input["command"].to_s.truncate(MAX_SUMMARY_SIZE),
        "timeout" => input["timeout"],
        "workdir" => input["workdir"]
      }
    else
      # Unknown tool — return all keys truncated
      input.transform_values { |v| v.is_a?(String) ? v.truncate(MAX_SUMMARY_SIZE) : v }
    end
  end

  def generate_assertions(actions)
    assertions = []

    # File existence assertions (deduplicated)
    file_paths = actions
      .select { |a| FILE_TOOLS.include?(a["tool"]) }
      .filter_map { |a| a.dig("input_summary", "file_path") }
      .uniq

    file_paths.each do |path|
      assertions << {
        "type" => "file_exists",
        "path" => path,
        "description" => "File #{File.basename(path)} should exist after agent run"
      }
    end

    # Test pass assertions
    actions
      .select { |a| EXEC_TOOLS.include?(a["tool"]) }
      .each do |action|
        cmd = action.dig("input_summary", "command").to_s
        if cmd.match?(/\b(test|spec|rspec|jest|pytest)\b/i)
          assertions << {
            "type" => "tests_pass",
            "command" => cmd,
            "description" => "Tests should pass: #{cmd.truncate(100)}"
          }
        elsif cmd.match?(/ruby\s+-c\b|node\s+-c\b/)
          assertions << {
            "type" => "syntax_valid",
            "command" => cmd,
            "description" => "Syntax check should pass: #{cmd.truncate(100)}"
          }
        end
      end

    assertions
  end

  def build_metadata(actions, transcript_path)
    tool_counts = actions.group_by { |a| a["tool"] }.transform_values(&:count)
    file_paths = actions
      .select { |a| FILE_TOOLS.include?(a["tool"]) }
      .filter_map { |a| a.dig("input_summary", "file_path") }
      .uniq

    {
      "tool_counts" => tool_counts,
      "total_tool_calls" => actions.size,
      "file_count" => file_paths.size,
      "files_modified" => file_paths,
      "transcript_path" => transcript_path,
      "recorded_at" => Time.current.iso8601
    }
  end

  def generate_test_code(actions, assertions)
    task_name = @task.name.to_s.gsub(/[^a-zA-Z0-9_\s]/, "").strip.gsub(/\s+/, "_")
    class_name = "AgentReplay#{task_name.camelize.truncate(40, omission: '')}Test"

    lines = [
      '# frozen_string_literal: true',
      '',
      'require "test_helper"',
      '',
      "class #{class_name} < ActiveSupport::TestCase",
    ]

    assertions.each do |assertion|
      case assertion["type"]
      when "file_exists"
        test_name = "test \"file exists: #{File.basename(assertion['path'])}\" do"
        lines << "  #{test_name}"
        lines << "    assert File.exist?(#{assertion['path'].inspect}), \"Expected #{assertion['path']} to exist\""
        lines << "  end"
        lines << ""
      when "tests_pass"
        test_name = "test \"tests pass: #{assertion['command'].truncate(60)}\" do"
        lines << "  #{test_name}"
        lines << "    output = `#{assertion['command']} 2>&1`"
        lines << "    assert $?.success?, \"Test command failed: \#{output.last(500)}\""
        lines << "  end"
        lines << ""
      when "syntax_valid"
        test_name = "test \"syntax valid: #{assertion['command'].truncate(60)}\" do"
        lines << "  #{test_name}"
        lines << "    output = `#{assertion['command']} 2>&1`"
        lines << "    assert $?.success?, \"Syntax check failed: \#{output.last(500)}\""
        lines << "  end"
        lines << ""
      end
    end

    lines << "end"
    lines.join("\n")
  end
end
