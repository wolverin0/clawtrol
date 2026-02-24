# frozen_string_literal: true

require "digest"

class SwarmTaskContract
  VERSION = "2026-02-23.v1"

  DEFAULT_REQUIRED_ARTIFACTS = [
    "Code changes or explicit no-code decision",
    "Validation evidence (tests/lint/checks)",
    "Short execution summary"
  ].freeze

  class << self
    def build(idea:, board_id:, model:, overrides: {})
      normalized = normalize_overrides(overrides)

      contract = {
        "version" => VERSION,
        "generated_at" => Time.current.utc.iso8601,
        "orchestrator" => normalized[:orchestrator].presence || "swarm",
        "phase" => normalized[:phase].presence || "single_phase",
        "idea" => {
          "id" => idea.id,
          "title" => idea.title.to_s,
          "description" => idea.description.to_s,
          "category" => idea.category.to_s,
          "difficulty" => idea.difficulty.to_s,
          "source" => idea.source.to_s,
          "project" => idea.project.to_s
        },
        "execution" => {
          "board_id" => board_id.to_i,
          "model" => model.to_s,
          "pipeline_type" => idea.pipeline_type.presence || "feature",
          "estimated_minutes" => idea.estimated_minutes.to_i
        },
        "acceptance_criteria" => normalized[:acceptance_criteria].presence || default_acceptance_criteria(idea),
        "required_artifacts" => normalized[:required_artifacts].presence || DEFAULT_REQUIRED_ARTIFACTS,
        "skills" => normalized[:skills]
      }

      contract["contract_id"] = digest_for(contract)
      contract
    end

    def validate(contract)
      errors = []
      payload = contract.is_a?(Hash) ? contract : {}

      errors << "version missing" if payload["version"].blank?
      errors << "contract_id missing" if payload["contract_id"].blank?

      idea = payload["idea"] || {}
      execution = payload["execution"] || {}

      errors << "idea.title missing" if idea["title"].blank?
      errors << "execution.board_id missing" if execution["board_id"].to_i <= 0
      errors << "execution.model missing" if execution["model"].blank?

      criteria = Array(payload["acceptance_criteria"]).map(&:to_s).map(&:strip).reject(&:blank?)
      artifacts = Array(payload["required_artifacts"]).map(&:to_s).map(&:strip).reject(&:blank?)

      errors << "acceptance_criteria must include at least one item" if criteria.empty?
      errors << "required_artifacts must include at least one item" if artifacts.empty?

      {
        valid: errors.empty?,
        errors: errors
      }
    end

    def render_execution_prompt(contract)
      payload = contract.is_a?(Hash) ? contract : {}
      criteria = Array(payload["acceptance_criteria"]).map(&:to_s).map(&:strip).reject(&:blank?)
      artifacts = Array(payload["required_artifacts"]).map(&:to_s).map(&:strip).reject(&:blank?)

      lines = []
      lines << "Swarm Contract ID: #{payload['contract_id']}"
      lines << "Model: #{payload.dig('execution', 'model')}"
      lines << "Board ID: #{payload.dig('execution', 'board_id')}"
      lines << ""
      lines << "Acceptance Criteria:"
      criteria.each { |item| lines << "- #{item}" }
      lines << ""
      lines << "Required Artifacts:"
      artifacts.each { |item| lines << "- #{item}" }

      lines.join("\n")
    end

    private

    def normalize_overrides(overrides)
      raw = overrides.is_a?(Hash) ? overrides : {}

      {
        orchestrator: raw[:orchestrator] || raw["orchestrator"],
        phase: raw[:phase] || raw["phase"],
        acceptance_criteria: normalize_list(raw[:acceptance_criteria] || raw["acceptance_criteria"]),
        required_artifacts: normalize_list(raw[:required_artifacts] || raw["required_artifacts"]),
        skills: normalize_list(raw[:skills] || raw["skills"])
      }
    end

    def normalize_list(value)
      case value
      when nil
        []
      when Array
        value.map(&:to_s).map(&:strip).reject(&:blank?)
      else
        value.to_s.split(/[\n,]/).map(&:strip).reject(&:blank?)
      end
    end

    def default_acceptance_criteria(idea)
      [
        "Deliver the objective for '#{idea.title}'",
        "Keep changes scoped and reversible",
        "Include validation results relevant to touched code"
      ]
    end

    def digest_for(contract)
      Digest::SHA256.hexdigest(contract.to_json)[0, 16]
    end
  end
end
