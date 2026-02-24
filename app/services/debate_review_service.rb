# frozen_string_literal: true

require "fileutils"
require "json"

# Executes a multi-model review gate for a task.
# Primary path: OpenClaw gateway session spawn + transcript polling.
# Fallback path: deterministic local rubric when gateway tools are unavailable.
class DebateReviewService
  DEFAULT_MODELS = %w[gemini claude glm].freeze
  MAX_WAIT_SECONDS = ENV.fetch("DEBATE_REVIEW_MAX_WAIT_SECONDS", "45").to_i
  POLL_INTERVAL_SECONDS = 2
  SUMMARY_LIMIT = 4500

  GATE_MODELS = {
    "gemini" => "gemini3",
    "claude" => "opus",
    "glm" => "glm",
    "codex" => "codex"
  }.freeze

  def initialize(task, gateway_client: nil, logger: Rails.logger)
    @task = task
    @gateway_client = gateway_client || OpenclawGatewayClient.new(task.user)
    @logger = logger
  end

  def call
    models = resolved_models
    reviews = models.map { |model| review_with_model(model) }
    synthesis = build_synthesis(reviews)

    write_synthesis_file!(synthesis, reviews)

    {
      status: synthesis[:gate_status],
      result: {
        gate_status: synthesis[:gate_status],
        gate_reason: synthesis[:gate_reason],
        review_models: models,
        completed_models: reviews.count { |review| review[:verdict].present? },
        failed_models: reviews.count { |review| review[:error].present? },
        synthesis_preview: synthesis[:summary],
        debate_path: @task.debate_synthesis_path,
        reviews: reviews,
        not_implemented: false
      }
    }
  rescue StandardError => e
    {
      status: "failed",
      result: {
        error_summary: "Debate review crashed: #{e.message}",
        not_implemented: false
      }
    }
  end

  private

  def resolved_models
    configured = Array(@task.review_config["models"]).map { |value| value.to_s.downcase.strip }.reject(&:blank?)
    selected = configured.presence || DEFAULT_MODELS
    selected.select { |model| GATE_MODELS.key?(model) }.uniq.first(4)
  end

  def review_with_model(model)
    prompt = debate_prompt(model)
    gateway_model = GATE_MODELS.fetch(model, model)

    spawn = @gateway_client.spawn_session!(model: gateway_model, prompt: prompt)
    session_key = spawn[:child_session_key]

    if session_key.blank?
      return local_rubric_review(
        model,
        gateway_model: gateway_model,
        reason: "No child session key returned by gateway"
      )
    end

    response_text = wait_for_assistant_response(session_key)
    parsed = parse_review_response(response_text)

    review = {
      model: model,
      gateway_model: gateway_model,
      session_key: session_key,
      verdict: parsed[:verdict],
      confidence: parsed[:confidence],
      major_risks: parsed[:major_risks],
      minor_risks: parsed[:minor_risks],
      recommended_actions: parsed[:recommended_actions],
      summary: parsed[:summary],
      raw_response: response_text.to_s.truncate(1500),
      error: parsed[:error],
      source: "gateway"
    }

    return review if review[:verdict].present?

    local_rubric_review(
      model,
      gateway_model: gateway_model,
      reason: parsed[:error].presence || "Missing verdict",
      raw_response: response_text,
      session_key: session_key
    )
  rescue StandardError => e
    local_rubric_review(
      model,
      gateway_model: GATE_MODELS.fetch(model, model),
      reason: e.message
    )
  end

  def local_rubric_review(model, gateway_model:, reason: nil, raw_response: nil, session_key: nil)
    major_risks = []
    minor_risks = []
    recommended_actions = []

    latest_run = @task.task_runs.order(created_at: :desc).first
    has_output = @task.has_agent_output? || Array(@task.output_files).any?

    unless has_output
      major_risks << "No explicit agent output marker/files found on task"
      recommended_actions << "Capture agent output before review gate"
    end

    if @task.validation_status.to_s == "failed"
      major_risks << "Validation status is failed"
      recommended_actions << "Fix failing validation command before merge"
    end

    if @task.error_message.present?
      major_risks << "Task has recorded error message"
      recommended_actions << "Resolve task error and rerun"
    end

    if latest_run.nil?
      minor_risks << "No task run records found"
      recommended_actions << "Run task once through outcome contract"
    else
      if latest_run.needs_follow_up?
        minor_risks << "Latest run requested follow-up"
        recommended_actions << "Address follow-up checklist from last run"
      end

      if latest_run.recommended_action.to_s == "requeue_same_task"
        minor_risks << "Latest run recommended requeue"
        recommended_actions << "Execute follow-up prompt and rerun gate"
      end
    end

    verdict = major_risks.empty? ? "pass" : "fail"
    confidence = major_risks.empty? ? 72 : 68

    summary = if verdict == "pass"
      "Local rubric fallback: no major blockers detected. Ready for in-review handoff."
    else
      "Local rubric fallback: blockers detected (#{major_risks.first(2).join('; ')})."
    end

    {
      model: model,
      gateway_model: gateway_model,
      session_key: session_key,
      verdict: verdict,
      confidence: confidence,
      major_risks: major_risks,
      minor_risks: minor_risks,
      recommended_actions: recommended_actions.uniq,
      summary: summary.truncate(700),
      raw_response: raw_response.to_s.truncate(1500),
      error: reason.present? ? "Gateway unavailable, local rubric used: #{reason}" : nil,
      source: "local_rubric_fallback"
    }
  end

  def wait_for_assistant_response(session_key)
    deadline = Time.current + MAX_WAIT_SECONDS.seconds

    loop do
      result = @gateway_client.sessions_history(session_key, limit: 40)
      messages = Array(result["messages"])
      assistant = messages.reverse.find { |message| message["role"].to_s == "assistant" && message["content"].present? }

      return assistant["content"].to_s if assistant

      break if Time.current >= deadline

      sleep POLL_INTERVAL_SECONDS
    end

    ""
  end

  def parse_review_response(text)
    payload = extract_json_payload(text)

    if payload.is_a?(Hash)
      verdict = payload["verdict"].to_s.downcase
      verdict = %w[pass fail].include?(verdict) ? verdict : nil

      confidence = payload["confidence"].to_i
      confidence = confidence.clamp(0, 100)

      {
        verdict: verdict,
        confidence: confidence,
        major_risks: normalize_list(payload["major_risks"]),
        minor_risks: normalize_list(payload["minor_risks"]),
        recommended_actions: normalize_list(payload["recommended_actions"]),
        summary: payload["summary"].to_s.truncate(700),
        error: verdict.present? ? nil : "Missing verdict"
      }
    else
      fallback_verdict = infer_verdict_from_text(text)
      {
        verdict: fallback_verdict,
        confidence: nil,
        major_risks: [],
        minor_risks: [],
        recommended_actions: [],
        summary: text.to_s.truncate(700),
        error: "Could not parse strict JSON response"
      }
    end
  rescue StandardError => e
    {
      verdict: nil,
      confidence: nil,
      major_risks: [],
      minor_risks: [],
      recommended_actions: [],
      summary: text.to_s.truncate(700),
      error: "Parse error: #{e.message}"
    }
  end

  def extract_json_payload(text)
    return nil if text.blank?

    direct = JSON.parse(text) rescue nil
    return direct if direct.is_a?(Hash)

    code_block = text.to_s.match(/```json\s*(\{.*?\})\s*```/m)
    if code_block
      parsed = JSON.parse(code_block[1]) rescue nil
      return parsed if parsed.is_a?(Hash)
    end

    generic = text.to_s.match(/(\{.*\})/m)
    if generic
      parsed = JSON.parse(generic[1]) rescue nil
      return parsed if parsed.is_a?(Hash)
    end

    nil
  end

  def infer_verdict_from_text(text)
    lower = text.to_s.downcase
    return "fail" if lower.include?("verdict: fail") || lower.include?("\"verdict\":\"fail\"")
    return "pass" if lower.include?("verdict: pass") || lower.include?("\"verdict\":\"pass\"")
    return "fail" if lower.include?("critical") || lower.include?("blocker")

    nil
  end

  def normalize_list(value)
    case value
    when Array
      value.map(&:to_s).map(&:strip).reject(&:blank?).first(8)
    when String
      value.lines.map(&:strip).reject(&:blank?).first(8)
    else
      []
    end
  end

  def build_synthesis(reviews)
    completed = reviews.select { |review| review[:verdict].present? }
    pass_count = completed.count { |review| review[:verdict] == "pass" }
    fail_count = completed.count { |review| review[:verdict] == "fail" }

    critical_fail = completed.any? do |review|
      review[:verdict] == "fail" && review[:major_risks].any? { |risk| risk.to_s.downcase.match?(/critical|security|data loss|exploit/) }
    end

    gate_status = if completed.size < 2
      "failed"
    elsif critical_fail
      "failed"
    elsif pass_count > fail_count
      "passed"
    else
      "failed"
    end

    gate_reason = if completed.size < 2
      "Not enough completed model reviews to form a consensus"
    elsif critical_fail
      "At least one reviewer found a critical/security blocker"
    elsif pass_count > fail_count
      "Majority pass consensus"
    else
      "Majority fail or tie consensus"
    end

    summary_lines = []
    summary_lines << "Gate result: #{gate_status.upcase}"
    summary_lines << "Reason: #{gate_reason}"
    summary_lines << "Completed reviews: #{completed.size}/#{reviews.size}"
    summary_lines << "Pass votes: #{pass_count}"
    summary_lines << "Fail votes: #{fail_count}"

    reviews.each do |review|
      summary_lines << ""
      summary_lines << "[#{review[:model]}] verdict=#{review[:verdict] || 'unknown'} confidence=#{review[:confidence] || 'n/a'} source=#{review[:source] || 'unknown'}"
      summary_lines << "summary: #{review[:summary]}" if review[:summary].present?
      summary_lines << "major_risks: #{review[:major_risks].join('; ')}" if review[:major_risks].any?
      summary_lines << "recommended_actions: #{review[:recommended_actions].join('; ')}" if review[:recommended_actions].any?
      summary_lines << "error: #{review[:error]}" if review[:error].present?
    end

    {
      gate_status: gate_status,
      gate_reason: gate_reason,
      summary: summary_lines.join("\n").truncate(SUMMARY_LIMIT)
    }
  end

  def write_synthesis_file!(synthesis, reviews)
    FileUtils.mkdir_p(@task.debate_storage_path)

    lines = []
    lines << "# Debate Review Synthesis"
    lines << ""
    lines << "Task: ##{@task.id} #{@task.name}"
    lines << "Generated at: #{Time.current.iso8601}"
    lines << ""
    lines << "## Gate"
    lines << "- Status: #{synthesis[:gate_status].upcase}"
    lines << "- Reason: #{synthesis[:gate_reason]}"
    lines << ""
    lines << "## Model Reviews"

    reviews.each do |review|
      lines << "### #{review[:model]} (#{review[:gateway_model]})"
      lines << "- Source: #{review[:source] || 'unknown'}"
      lines << "- Session key: #{review[:session_key] || 'n/a'}"
      lines << "- Verdict: #{review[:verdict] || 'unknown'}"
      lines << "- Confidence: #{review[:confidence] || 'n/a'}"
      lines << "- Summary: #{review[:summary] || 'n/a'}"
      lines << "- Major risks: #{review[:major_risks].join('; ').presence || 'none'}"
      lines << "- Minor risks: #{review[:minor_risks].join('; ').presence || 'none'}"
      lines << "- Recommended actions: #{review[:recommended_actions].join('; ').presence || 'none'}"
      lines << "- Error: #{review[:error]}" if review[:error].present?
      lines << ""
    end

    File.write(@task.debate_synthesis_path, lines.join("\n"))
  rescue StandardError => e
    @logger.warn("[DebateReviewService] Failed to write synthesis file task_id=#{@task.id}: #{e.message}")
  end

  def debate_prompt(model)
    <<~PROMPT
      You are a strict independent reviewer in a cross-model gate.
      Return ONLY valid JSON (no markdown, no prose outside JSON):
      {
        "verdict": "pass|fail",
        "confidence": 0,
        "major_risks": ["..."],
        "minor_risks": ["..."],
        "recommended_actions": ["..."],
        "summary": "short explanation"
      }

      Evaluation rules:
      - Use FAIL if there is any correctness, security, data integrity, or missing-validation blocker.
      - Use PASS only if output is production-safe for handoff to human review.
      - Keep summary under 80 words.

      Task context:
      - Task ID: #{@task.id}
      - Task name: #{@task.name}
      - Task status: #{@task.status}
      - Requested model participant: #{model}
      - Review config style: #{@task.review_config["style"].presence || "quick"}
      - Focus: #{@task.review_config["focus"].presence || "(none)"}

      Task description excerpt:
      #{task_description_excerpt}

      Latest run excerpt:
      #{latest_run_excerpt}
    PROMPT
  end

  def task_description_excerpt
    @task.description.to_s.truncate(3500)
  end

  def latest_run_excerpt
    run = @task.task_runs.order(created_at: :desc).first
    return "No task run available." unless run

    payload_excerpt = run.raw_payload.to_json.truncate(1500)
    <<~TXT
      - Run ID: #{run.run_id}
      - Summary: #{run.summary}
      - Recommended action: #{run.recommended_action}
      - Needs follow-up: #{run.needs_follow_up?}
      - Payload excerpt: #{payload_excerpt}
    TXT
  end
end
