# frozen_string_literal: true

# Standardized contract for sub-agent output.
# Fields: summary, changes, validation, follow_up, recommended_action.
class SubAgentOutputContract
  CONTRACT_KEYS = %w[summary changes validation follow_up recommended_action].freeze

  def self.from_params(params)
    raw = extract_contract(params)
    return nil if raw.blank?

    new(raw)
  end

  def self.normalize(payload)
    contract = from_params(payload)
    return {} unless contract

    contract.to_payload
  end

  def initialize(raw)
    @raw = (raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw.to_h).with_indifferent_access
  end

  def summary
    @raw["summary"].to_s.presence
  end

  def changes
    normalize_list(@raw["changes"])
  end

  def validation
    val = @raw["validation"]
    return val if val.is_a?(Hash)

    val.to_s.presence
  end

  def follow_up
    normalize_list(@raw["follow_up"])
  end

  def recommended_action
    @raw["recommended_action"].to_s.presence
  end

  def to_payload
    {
      "summary" => summary,
      "changes" => changes,
      "validation" => validation,
      "follow_up" => follow_up,
      "recommended_action" => recommended_action
    }.compact
  end

  def to_markdown
    sections = []
    sections << section("Summary", summary) if summary.present?
    sections << section("Changes", list_or_text(changes)) if changes.any?
    sections << section("Validation", format_validation(validation)) if validation.present?
    sections << section("Follow-up", list_or_text(follow_up)) if follow_up.any?
    sections << section("Recommended Action", recommended_action) if recommended_action.present?
    sections.compact.join("\n\n")
  end

  private

  def section(title, body)
    return nil if body.blank?

    "### #{title}\n#{body}"
  end

  def list_or_text(list)
    list.map { |item| "- #{item}" }.join("\n")
  end

  def format_validation(val)
    return val if val.is_a?(String)
    return nil unless val.is_a?(Hash)

    val.map { |key, value| "- #{key}: #{value}" }.join("\n")
  end

  def normalize_list(value)
    case value
    when Array
      value.map(&:to_s).map(&:strip).reject(&:blank?)
    when String
      value.lines.map(&:strip).reject(&:blank?)
    else
      []
    end
  end

  def self.extract_contract(params)
    return params if params.is_a?(Hash) && CONTRACT_KEYS.any? { |k| params.key?(k) || params.key?(k.to_sym) }

    source = params.is_a?(ActionController::Parameters) ? params.to_unsafe_h : params.to_h
    contract = source["output_contract"] || source[:output_contract] ||
      source["sub_agent_output"] || source[:sub_agent_output] ||
      source["agent_output_contract"] || source[:agent_output_contract]

    contract if contract.is_a?(Hash) || contract.is_a?(ActionController::Parameters)
  end
end
