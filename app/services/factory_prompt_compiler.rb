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

      Stack detection:
      - framework: #{@stack_info[:framework]}
      - language: #{@stack_info[:language]}
      - test_command: #{@stack_info[:test_command]}
      - syntax_check: #{@stack_info[:syntax_check]}

      Recent improvement log entries (last 5):
      #{format_list(recent_improvement_entries)}

      Unchecked backlog items:
      #{format_list(unchecked_backlog_items)}

      Recent known findings (avoid duplicates):
      #{format_list(recent_patterns)}
    PROMPT
  end

  private

  def workspace_path
    @loop.workspace_path.presence || Rails.root.to_s
  end

  def improvement_log_path
    File.join(workspace_path, "IMPROVEMENT_LOG.md")
  end

  def backlog_path
    configured = @loop.respond_to?(:backlog_path) ? @loop.backlog_path : nil
    File.join(workspace_path, configured.presence || "FACTORY_BACKLOG.md")
  end

  def recent_improvement_entries
    return [] unless File.exist?(improvement_log_path)

    File.readlines(improvement_log_path, chomp: true)
        .map(&:strip)
        .reject(&:blank?)
        .last(5)
  rescue StandardError
    []
  end

  def unchecked_backlog_items
    return [] unless File.exist?(backlog_path)

    File.readlines(backlog_path, chomp: true)
        .filter_map do |line|
      normalized = line.strip
      next unless normalized.start_with?("- [ ]")

      normalized.sub(/^- \[ \]\s*/, "")
    end
  rescue StandardError
    []
  end

  def recent_patterns
    @loop.factory_finding_patterns.order(updated_at: :desc).limit(10).map do |pattern|
      category = pattern.category.presence || "uncategorized"
      "[#{category}] #{pattern.description}"
    end
  end

  def format_list(items)
    return "- none" if items.blank?

    items.map { |entry| "- #{entry}" }.join("\n")
  end
end
