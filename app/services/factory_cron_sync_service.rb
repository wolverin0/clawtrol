# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

class FactoryCronSyncService
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 30

  class << self
    def create_cron(factory_loop)
      factory_agent = first_enabled_agent_for(factory_loop)
      stack_info = FactoryStackDetector.call(factory_loop.workspace_path)
      compiled_context = FactoryPromptCompiler.call(
        factory_loop: factory_loop,
        factory_agent: factory_agent,
        stack_info: stack_info
      )

      response = request_json(
        :post,
        "/api/cron/jobs",
        body: {
          name: "🏭 Factory: #{factory_loop.name}",
          enabled: true,
          schedule: {
            kind: "every",
            everyMs: factory_loop.interval_ms
          },
          sessionTarget: "isolated",
          payload: {
            kind: "agentTurn",
            model: model_identifier(factory_loop.model),
            message: build_prompt_message(factory_loop, stack_info, compiled_context),
            timeoutSeconds: timeout_seconds(factory_loop)
          },
          delivery: {
            mode: "none"
          }
        }
      )

      cron_id = response["id"] || response.dig("job", "id") || response.dig("data", "id")
      factory_loop.update!(openclaw_cron_id: cron_id) if cron_id.present?

      response
    end

    def pause_cron(factory_loop)
      return unless factory_loop.openclaw_cron_id.present?

      request_json(:patch, "/api/cron/jobs/#{factory_loop.openclaw_cron_id}", body: { enabled: false })
    end

    def resume_cron(factory_loop)
      return unless factory_loop.openclaw_cron_id.present?

      request_json(:patch, "/api/cron/jobs/#{factory_loop.openclaw_cron_id}", body: { enabled: true })
    end

    def delete_cron(factory_loop)
      return unless factory_loop.openclaw_cron_id.present?

      request_json(:delete, "/api/cron/jobs/#{factory_loop.openclaw_cron_id}")
      factory_loop.update!(openclaw_cron_id: nil)
    end

    private

    def gateway_url
      ENV.fetch("OPENCLAW_GATEWAY_URL", "http://localhost:18789")
    end

    def gateway_token
      ENV.fetch("OPENCLAW_GATEWAY_TOKEN", "")
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
      }.fetch(model_alias, model_alias)
    end

    def timeout_seconds(factory_loop)
      max_minutes = factory_loop.max_session_minutes.presence || 240
      [ (max_minutes * 60) - 60, 60 ].max
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

    def request_json(method, path, body: nil)
      base = URI.parse(gateway_url)
      uri = base.dup
      uri.path = path

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = request_for(method, uri)
      request["Authorization"] = "Bearer #{gateway_token}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json if body

      response = http.request(request)
      code = response.code.to_i
      parsed = JSON.parse(response.body.to_s.presence || "{}")

      raise "OpenClaw cron API HTTP #{code}: #{parsed}" unless code.between?(200, 299)

      parsed
    end

    def request_for(method, uri)
      case method.to_sym
      when :post then Net::HTTP::Post.new(uri)
      when :patch then Net::HTTP::Patch.new(uri)
      when :delete then Net::HTTP::Delete.new(uri)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end
  end
end
