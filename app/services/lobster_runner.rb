# frozen_string_literal: true

require "yaml"
require "open3"
require "securerandom"

class LobsterRunner
  PIPELINE_DIR = Rails.root.join("lobster")
  TIMEOUT_SECONDS = 30

  Result = Struct.new(:success, :output, :resume_token, :waiting_approval, :error, keyword_init: true)

  def self.run(pipeline_name, task:, args: {})
    new(pipeline_name, task: task, args: args).run
  end

  def self.resume(task, approve:)
    new(nil, task: task).resume(approve: approve)
  end

  def initialize(pipeline_name, task:, args: {})
    @pipeline_name = pipeline_name
    @task = task
    @args = args
  end

  def run
    pipeline_file = PIPELINE_DIR.join("#{@pipeline_name}.lobster")
    return Result.new(success: false, error: "Pipeline not found: #{@pipeline_name}") unless pipeline_file.exist?

    pipeline = YAML.load_file(pipeline_file)
    steps = pipeline["steps"] || []
    outputs = []

    steps.each do |step|
      cmd = interpolate(step["command"], @args.merge("task_id" => @task.id.to_s))

      if step["approval"] == "required"
        token = SecureRandom.hex(16)
        @task.update!(
          resume_token: token,
          lobster_status: "waiting_approval",
          lobster_pipeline: @pipeline_name
        )
        return Result.new(
          success: true,
          output: outputs.join("\n"),
          resume_token: token,
          waiting_approval: true
        )
      end

      stdout, stderr, status = Open3.capture3(cmd)
      output = stdout.presence || stderr.presence || "(no output)"
      outputs << "[#{step["id"]}] #{output.strip}"

      unless status.success?
        return Result.new(success: false, output: outputs.join("\n"), error: "Step '#{step["id"]}' failed: #{stderr.strip}")
      end
    end

    @task.update!(lobster_status: "completed", resume_token: nil)
    Result.new(success: true, output: outputs.join("\n"))
  rescue => e
    Result.new(success: false, error: e.message)
  end

  def resume(approve:)
    unless approve
      @task.update!(lobster_status: "rejected", resume_token: nil)
      return Result.new(success: true, output: "Pipeline rejected by user.")
    end

    pipeline_name = @task.lobster_pipeline
    return Result.new(success: false, error: "No pipeline stored on task") unless pipeline_name.present?

    pipeline_file = PIPELINE_DIR.join("#{pipeline_name}.lobster")
    return Result.new(success: false, error: "Pipeline not found: #{pipeline_name}") unless pipeline_file.exist?

    pipeline = YAML.load_file(pipeline_file)
    steps = pipeline["steps"] || []
    approval_idx = steps.index { |s| s["approval"] == "required" }
    remaining = approval_idx ? steps[(approval_idx + 1)..] : []

    outputs = []
    remaining.each do |step|
      cmd = interpolate(step["command"], { "task_id" => @task.id.to_s })
      stdout, stderr, status = Open3.capture3(cmd)
      output = stdout.presence || stderr.presence || "(no output)"
      outputs << "[#{step["id"]}] #{output.strip}"
    end

    @task.update!(lobster_status: "completed", resume_token: nil)
    Result.new(success: true, output: outputs.join("\n"))
  rescue => e
    Result.new(success: false, error: e.message)
  end

  private

  def interpolate(cmd, vars)
    cmd.gsub(/\$(\w+)/) { vars[$1] || ENV[$1] || "" }
  end
end
