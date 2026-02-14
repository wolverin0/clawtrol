# frozen_string_literal: true

# Automatically tags tasks based on title and description content.
# Used by QuickAddController and API task creation for consistent auto-tagging.
#
# Usage:
#   tags = AutoTaggerService.tag("Fix SQL injection in login controller")
#   # => ["security", "sql", "bug", "fix"]
#
#   model = AutoTaggerService.suggest_model(tags)
#   # => "gemini" (for research tasks) or nil
class AutoTaggerService
  # Keyword → tags mapping. Order matters for priority display.
  RULES = {
    # Security
    "security" => %w[security],
    "xss" => %w[security xss],
    "csrf" => %w[security csrf],
    "sql injection" => %w[security sql-injection],
    "sql" => %w[security sql],
    "auth" => %w[security auth],
    "idor" => %w[security idor],
    "token" => %w[security],

    # Bug/Fix
    "bug" => %w[bug fix],
    "fix" => %w[bug fix],
    "error" => %w[bug],
    "crash" => %w[bug],
    "broken" => %w[bug],
    "nil" => %w[bug],

    # Code Quality
    "refactor" => %w[code-quality refactor],
    "extract" => %w[code-quality refactor],
    "dry" => %w[code-quality],
    "cleanup" => %w[code-quality],
    "concern" => %w[code-quality refactor],
    "service object" => %w[code-quality architecture],

    # Testing
    "test" => %w[testing],
    "spec" => %w[testing],
    "coverage" => %w[testing],

    # Performance
    "performance" => %w[performance],
    "slow" => %w[performance],
    "n+1" => %w[performance],
    "cache" => %w[performance],
    "index" => %w[performance],
    "query" => %w[performance],

    # Frontend
    "ui" => %w[frontend ui],
    "css" => %w[frontend css],
    "tailwind" => %w[frontend css],
    "responsive" => %w[frontend responsive],
    "stimulus" => %w[frontend stimulus],
    "turbo" => %w[frontend turbo],
    "accessibility" => %w[frontend a11y],
    "aria" => %w[frontend a11y],
    "modal" => %w[frontend ui],

    # Backend
    "api" => %w[backend api],
    "endpoint" => %w[backend api],
    "controller" => %w[backend],
    "model" => %w[backend],
    "migration" => %w[backend database],
    "database" => %w[backend database],

    # Infrastructure
    "deploy" => %w[infrastructure deploy],
    "docker" => %w[infrastructure docker],
    "ci" => %w[infrastructure ci-cd],
    "cd" => %w[infrastructure ci-cd],

    # Network (ISP-specific)
    "mikrotik" => %w[network mikrotik],
    "unifi" => %w[network unifi],
    "uisp" => %w[network uisp],
    "router" => %w[network],
    "firewall" => %w[network security],

    # Research
    "research" => %w[research],
    "investigate" => %w[research],
    "evaluate" => %w[research],
    "compare" => %w[research],
    "study" => %w[research],

    # Architecture
    "architecture" => %w[architecture],
    "design" => %w[architecture],
    "pattern" => %w[architecture],
    "service" => %w[architecture],
  }.freeze

  # @param text [String] task title + optional description
  # @param max_tags [Integer] maximum number of tags to return
  # @return [Array<String>] unique tags sorted by relevance
  def self.tag(text, max_tags: 10)
    return [] if text.blank?

    downcased = text.to_s.downcase
    tags = []

    # Multi-word rules first (more specific)
    RULES.sort_by { |k, _| -k.length }.each do |keyword, keyword_tags|
      tags.concat(keyword_tags) if downcased.include?(keyword)
    end

    tags.uniq.first(max_tags)
  end

  # Suggest a model based on detected tags
  # @param tags [Array<String>] auto-detected tags
  # @return [String, nil] suggested model or nil for default
  def self.suggest_model(tags)
    return nil if tags.blank?

    tag_set = tags.to_set

    return "gemini" if tag_set.include?("research") # Free tier for research
    return nil if tag_set.intersect?(Set.new(%w[frontend css ui])) # Human review for UI
    nil # Let pipeline or user decide
  end

  # Suggest a priority based on detected tags
  # @param tags [Array<String>] auto-detected tags
  # @return [String, nil] "high", "medium", "low", or nil
  def self.suggest_priority(tags)
    return nil if tags.blank?

    tag_set = tags.to_set

    return "high" if tag_set.intersect?(Set.new(%w[security bug crash]))
    return "medium" if tag_set.intersect?(Set.new(%w[performance]))
    nil
  end
end
