# frozen_string_literal: true

require "digest"
require "did_you_mean/levenshtein"

class FactoryFindingProcessor
  FACTORY_DEFAULT_BOARD_ID = 3

  def initialize(agent_run)
    @run = agent_run
    @loop = agent_run.factory_loop
    @agent = agent_run.factory_agent
    @loop_agent = FactoryLoopAgent.find_by(factory_loop: @loop, factory_agent: @agent)
  end

  def process!
    raw_findings = Array(@run.findings)
    return [] if raw_findings.empty?

    threshold = effective_threshold
    max_findings = @loop.max_findings_per_run || 5
    capped = raw_findings.first(max_findings)

    processed = capped.map { |finding| process_finding(finding, threshold) }

    @run.update!(
      findings: processed,
      findings_count: processed.count { |finding| visible_finding?(finding) },
      status: processed.any? { |finding| visible_finding?(finding) } ? "findings" : "clean"
    )

    processed
  end

  private

  def process_finding(raw_finding, threshold)
    finding = normalize_finding(raw_finding)
    description = finding["description"].to_s
    normalized_description = normalize_text(description)

    action = confidence_action(finding["confidence"], threshold)

    if action != "discarded" && normalized_description.present?
      pattern = upsert_pattern(description, normalized_description)
      if pattern.suppressed?
        finding["action"] = "suppressed"
        return finding
      end
    end

    if action == "auto_added"
      if duplicate_task?(description)
        finding["action"] = "duplicate"
      else
        create_backlog_task(finding)
        finding["action"] = "auto_added"
      end
    else
      finding["action"] = action
    end

    finding
  end

  def normalize_finding(raw_finding)
    finding_hash = raw_finding.is_a?(Hash) ? raw_finding.deep_stringify_keys : {}
    description = finding_hash["description"].presence || finding_hash["title"].presence || "Untitled finding"

    finding_hash.merge(
      "description" => description,
      "title" => finding_hash["title"].presence || description.truncate(80),
      "confidence" => confidence_value(finding_hash["confidence"])
    )
  end

  def confidence_value(value)
    Integer(value)
  rescue StandardError
    0
  end

  def confidence_action(confidence, threshold)
    return "discarded" if confidence < 40
    return "auto_added" if confidence >= threshold
    return "flagged" if confidence >= 70

    "visible"
  end

  def effective_threshold
    @loop_agent&.effective_confidence_threshold || @loop.confidence_threshold || @agent.default_confidence_threshold
  end

  def upsert_pattern(description, normalized_description)
    hash = Digest::SHA256.hexdigest(normalized_description)
    pattern = FactoryFindingPattern.find_or_initialize_by(factory_loop: @loop, pattern_hash: hash)
    return pattern if pattern.persisted?

    pattern.description = description
    pattern.category = @agent.category
    pattern.save!
    pattern
  end

  def duplicate_task?(description)
    normalized_description = normalize_text(description)
    return false if normalized_description.blank?

    Task.where(board_id: target_board_id).where.not(name: [nil, ""]).find_each do |task|
      return true if similar_text?(normalized_description, normalize_text(task.name.to_s))
    end

    false
  end

  def similar_text?(left, right)
    return false if left.blank? || right.blank?
    return true if left.include?(right) || right.include?(left)

    distance = DidYouMean::Levenshtein.distance(left, right)
    max_allowed_distance = [([left.length, right.length].max * 0.2).floor, 1].max
    distance <= max_allowed_distance
  end

  def normalize_text(text)
    text.to_s.downcase.gsub(/\s+/, " ").strip
  end

  def create_backlog_task(finding)
    Task.create!(
      name: finding["title"].to_s.truncate(255),
      description: build_task_description(finding),
      tags: [@agent.category, "factory-finding", "auto-generated"].compact,
      board_id: target_board_id,
      status: :inbox,
      user_id: @loop.user_id
    )
  end

  def build_task_description(finding)
    <<~TEXT.strip
      #{finding["description"]}

      Confidence: #{finding["confidence"]}
      Source agent: #{@agent.name} (#{@agent.slug})
      Factory loop: #{@loop.name} (##{@loop.id})
    TEXT
  end

  def target_board_id
    @target_board_id ||= begin
      configured_board_id = @loop.config.is_a?(Hash) ? @loop.config["board_id_for_findings"] : nil
      candidates = [configured_board_id, FACTORY_DEFAULT_BOARD_ID, @loop.user&.boards&.first&.id].compact
      found_board_id = candidates.find { |candidate_id| Board.exists?(id: candidate_id) }

      found_board_id || raise(ActiveRecord::RecordNotFound, "No board available for factory findings")
    end
  end

  def visible_finding?(finding)
    finding["action"] != "discarded" && finding["action"] != "suppressed"
  end
end
