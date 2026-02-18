# frozen_string_literal: true

require "json"
require "open3"

class FactoryCronSyncService
  class << self
    def create_cron(factory_loop)
      factory_agent = first_enabled_agent_for(factory_loop)
      stack_info = FactoryStackDetector.call(factory_loop.workspace_path)
      compiled_context = FactoryPromptCompiler.call(
        factory_loop: factory_loop,
        factory_agent: factory_agent,
        stack_info: stack_info
      )

      prompt = build_prompt_message(factory_loop, stack_info, compiled_context)
      interval_min = [(factory_loop.interval_ms / 60_000).round, 1].max

      cmd = [
        "openclaw", "cron", "add",
        "--name", "🏭 Factory: #{factory_loop.name}",
        "--every", "#{interval_min}m",
        "--session", "isolated",
        "--model", model_identifier(factory_loop.model),
        "--message", prompt,
        "--timeout-seconds", timeout_seconds(factory_loop).to_s,
        "--no-deliver",
        "--json"
      ]

      return {} unless cli_available?("openclaw")

      output, status = Open3.capture2(*cmd)
      raise "openclaw cron add failed (exit #{status.exitstatus}): #{output}" unless status.success?

      parsed = JSON.parse(output)
      cron_id = parsed["id"] || parsed.dig("job", "id")
      factory_loop.update!(openclaw_cron_id: cron_id) if cron_id.present?

      parsed
    end

    def pause_cron(factory_loop)
      return unless factory_loop.openclaw_cron_id.present?

      run_cli("openclaw", "cron", "disable", factory_loop.openclaw_cron_id)
    end

    def resume_cron(factory_loop)
      return unless factory_loop.openclaw_cron_id.present?

      run_cli("openclaw", "cron", "enable", factory_loop.openclaw_cron_id)
    end

    def delete_cron(factory_loop)
      return unless factory_loop.openclaw_cron_id.present?

      run_cli("openclaw", "cron", "rm", factory_loop.openclaw_cron_id, "--yes")
      factory_loop.update!(openclaw_cron_id: nil)
    end

    private

    def cli_available?(binary = "openclaw")
      system("which #{binary} > /dev/null 2>&1")
    end

    def run_cli(*cmd)
      return "" unless cli_available?(cmd.first)

      output, status = Open3.capture2(*cmd)
      Rails.logger.warn("FactoryCronSync CLI failed: #{cmd.join(' ')} → #{output}") unless status.success?
      output
    end

    def model_identifier(model_alias)
      {
        "minimax" => "ollama/minimax-m2.5:cloud",
        "opus" => "anthropic/claude-opus-4-6",
        "codex" => "openai-codex/gpt-5.3-codex",
        "gemini" => "google-gemini-cli/gemini-2.5-pro",
        "gemini-flash" => "google-gemini-cli/gemini-3-flash-preview",
        "glm" => "zai/glm-4.7",
        "deepseek" => "openrouter/deepseek/deepseek-r1-0528:free",
        "groq" => "groq/llama-3.3-70b-versatile",
        "cerebras" => "cerebras/llama-3.3-70b"
      }.fetch(model_alias.to_s, model_alias.to_s)
    end

    def timeout_seconds(factory_loop)
      max_minutes = factory_loop.max_session_minutes.presence || 240
      [(max_minutes * 60) - 60, 60].max
    end

    def first_enabled_agent_for(factory_loop)
      factory_loop.enabled_agents.by_priority.first ||
        raise("FactoryLoop ##{factory_loop.id} has no enabled agents")
    end

    def build_prompt_message(factory_loop, stack_info, compiled_context)
      workspace = factory_loop.workspace_path.presence || Rails.root.to_s
      minutes = factory_loop.max_session_minutes.presence || 240
      stack_label = stack_info[:framework].presence || stack_info[:language].presence || "software"
      project_name = File.basename(workspace)

      <<~PROMPT
        You are a senior #{stack_label} engineer running a CONTINUOUS improvement factory on #{project_name}.
        Workspace: #{workspace}
        This is an ISOLATED COPY. NEVER touch other directories.

        ## CONTINUOUS LOOP
        You have ~#{minutes} minutes. Run this cycle REPEATEDLY:
        1. ASSESS - check IMPROVEMENT_LOG.md, pick a different category
        2. CHOOSE improvement from: Security, Code Quality, Performance, Testing, Architecture, Bug Fixes
        3. IMPLEMENT the change
        4. VERIFY (syntax check + tests)
        5. COMMIT with [factory] prefix
        6. GO BACK TO STEP 1

        Rules: verify every change, revert on failure, rotate categories.

        Stack verification commands:
        - syntax_check: #{stack_info[:syntax_check]}
        - test_command: #{stack_info[:test_command]}

        #{compiled_context}
      PROMPT
    end
  end
end
