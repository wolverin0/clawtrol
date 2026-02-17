# frozen_string_literal: true

class FactoryPromptCompiler
  def self.call(factory_loop:, factory_agent:, stack_info:)
    new(factory_loop:, factory_agent:, stack_info:).call
  end

  def initialize(factory_loop:, factory_agent:, stack_info:)
    @loop = factory_loop
    @agent = factory_agent
    @stack_info = stack_info
  end

  def call
    <<~PROMPT
      #{@agent.system_prompt}

      Context:
      - loop: #{@loop.name} (##{@loop.id})
      - workspace: #{workspace_path}
      - framework: #{@stack_info[:framework]}
      - language: #{@stack_info[:language]}
      - syntax_check: #{@stack_info[:syntax_check]}
      - test_command: #{@stack_info[:test_command]}

      Backlog (open items):
      #{format_list(backlog_items)}

      Recent improvements (latest cycles):
      #{format_list(recent_improvements)}

      Known finding patterns (dedup target):
      #{format_list(finding_patterns)}

      Execution rules:
      - Keep changes minimal and safe.
      - Address one clear improvement from backlog when possible.
      - Avoid repeating known findings.
      - Ensure syntax check and tests pass before finishing.
      - If verification fails, revert the worktree to previous clean state.
    PROMPT
  end

  private

  def workspace_path
    @loop.workspace_path.presence || Rails.root.to_s
  end

  def backlog_file_path
    configured = @loop.respond_to?(:backlog_path) ? @loop.backlog_path : nil
    File.join(workspace_path, configured.presence || "FACTORY_BACKLOG.md")
  end

  def backlog_items
    return [] unless File.exist?(backlog_file_path)

    File.readlines(backlog_file_path, chomp: true)
        .map(&:strip)
        .filter_map do |line|
      next unless line.start_with?("- [ ]")

      line.sub(/^- \[ \]\s*/, "")
    end
  rescue StandardError
    []
  end

  def recent_improvements
    @loop.factory_cycle_logs.recent.limit(5).pluck(:summary).compact.map(&:strip).reject(&:blank?)
  end

  def finding_patterns
    scope = if @loop.factory_finding_patterns.respond_to?(:active)
      @loop.factory_finding_patterns.active
    else
      @loop.factory_finding_patterns
    end

    scope.order(updated_at: :desc).limit(10).map do |pattern|
      category = pattern.category.presence || "uncategorized"
      "[#{category}] #{pattern.description}"
    end
  end

  def format_list(items)
    return "- none" if items.blank?

    items.map { |item| "- #{item}" }.join("\n")
  end
end
