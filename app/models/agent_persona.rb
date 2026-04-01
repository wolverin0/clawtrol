# frozen_string_literal: true

class AgentPersona < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :agent_personas  # nil = shared/system persona
  belongs_to :board, optional: true, inverse_of: :agent_personas
  has_many :tasks, dependent: :nullify, inverse_of: :agent_persona, counter_cache: :tasks_count

  # Model options (same as Task)
  MODELS = Task::MODELS
  TIERS = %w[strategic-reasoning fast-coding research operations].freeze

  # Default tools available
  DEFAULT_TOOLS = %w[Read Write Edit exec web_search web_fetch browser nodes message].freeze

  EXEC_SECURITY_OPTIONS = %w[deny allowlist full].freeze
  EXEC_HOST_OPTIONS = %w[auto sandbox gateway node].freeze
  EXEC_ASK_OPTIONS = %w[off on-miss always].freeze

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "already exists for this user" }
  validates :model, length: { maximum: 120 }, allow_blank: true
  validates :fallback_model, length: { maximum: 120 }, allow_blank: true
  validates :tier, inclusion: { in: TIERS, allow_blank: true }
  validates :exec_security, inclusion: { in: EXEC_SECURITY_OPTIONS }, allow_blank: true
  validates :exec_host, inclusion: { in: EXEC_HOST_OPTIONS }, allow_blank: true
  validates :exec_ask, inclusion: { in: EXEC_ASK_OPTIONS }, allow_blank: true
  validates :exec_timeout, numericality: { greater_than: 0, less_than_or_equal_to: 3600 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_tier, ->(tier) { where(tier: tier) }
  scope :by_project, ->(project) { where(project: project) }
  scope :global, -> { where(project: "global") }
  scope :for_user, ->(user) { where(user_id: [nil, user&.id]) }
  scope :auto_generated, -> { where(auto_generated: true) }
  scope :for_board, ->(board) { where(board_id: board.id) }

  # Generate spawn prompt for agent
  def spawn_prompt
    prompt = ""
    prompt += "# #{name.titleize}\n\n" if name.present?
    prompt += "#{description}\n\n" if description.present?
    prompt += system_prompt if system_prompt.present?
    prompt
  end

  # Model display with fallback
  def model_chain
    [model, fallback_model].compact.join(" → ")
  end

  # Tools as array (handles both string and array)
  # Returns tools as a clean Array of strings.
  # Since `tools` is a PostgreSQL array column, Rails always casts the value
  # to an Array. The String branch is kept as a safety fallback.
  def tools_list
    case tools
    when Array then tools.select(&:present?)
    when String then tools.split(/,\s*/).map(&:strip).select(&:present?)
    else []
    end
  end

  # Handles assignment of comma-separated string to the tools array column.
  # Without this, assigning "Read, Write, exec" to a PG array column causes
  # incorrect parsing (PostgreSQL interprets it as array literal syntax).
  def tools=(value)
    if value.is_a?(String) && !value.start_with?("{")
      super(value.split(/,\s*/).map(&:strip).select(&:present?))
    else
      super
    end
  end

  # Tier badge color
  def tier_color
    case tier
    when "strategic-reasoning" then "purple"
    when "fast-coding" then "blue"
    when "research" then "green"
    when "operations" then "orange"
    else "gray"
    end
  end

  # Model badge color
  def model_color
    case model
    when "opus" then "purple"
    when "codex" then "blue"
    when "gemini" then "emerald"
    when "glm" then "amber"
    when "sonnet" then "orange"
    else "gray"
    end
  end

  # Build exec config hash for OpenClaw per-agent tools.exec
  def exec_config
    {
      security: exec_security.presence || "full",
      host: exec_host.presence || "auto",
      ask: exec_ask.presence || "off",
      timeout: exec_timeout || 300
    }.compact
  end

  # Import from YAML file
  def self.import_from_yaml(file_path, user: nil)
    return nil unless File.exist?(file_path)

    content = File.read(file_path)

    # Split YAML frontmatter from markdown content
    if content.start_with?("---")
      parts = content.split("---", 3)
      yaml_content = parts[1]
      markdown_content = parts[2]&.strip
    else
      yaml_content = content
      markdown_content = nil
    end

    data = YAML.safe_load(yaml_content, permitted_classes: [Symbol])
    return nil unless data

    persona = find_or_initialize_by(name: data["name"], user: user)
    persona.assign_attributes(
      description: data["description"],
      model: data["model"] || "sonnet",
      fallback_model: data["fallback"],
      tier: data["tier"],
      project: data["project"] || "global",
      tools: data["tools"] || [],
      system_prompt: markdown_content,
      active: true
    )

    # Auto-assign emoji based on name
    persona.emoji = emoji_for_name(data["name"]) unless persona.emoji.present? && persona.emoji != "🤖"

    persona.save!
    persona
  rescue StandardError => e
    Rails.logger.error "Failed to import persona from #{file_path}: #{e.message}"
    nil
  end

  # Import all personas from a directory
  def self.import_from_directory(dir_path, user: nil)
    imported = []

    # Import from root .yaml files
    Dir.glob(File.join(dir_path, "*.yaml")).each do |file|
      next if File.basename(file) == "registry.yaml"
      persona = import_from_yaml(file, user: user)
      imported << persona if persona
    end

    # Import from .md files
    Dir.glob(File.join(dir_path, "*.md")).each do |file|
      next if File.basename(file).downcase == "readme.md"
      next if File.basename(file).upcase.start_with?("SPAWN")
      persona = import_from_markdown(file, user: user)
      imported << persona if persona
    end

    # Import from subdirectories
    %w[global projects].each do |subdir|
      subdir_path = File.join(dir_path, subdir)
      next unless Dir.exist?(subdir_path)

      Dir.glob(File.join(subdir_path, "*.yaml")).each do |file|
        persona = import_from_yaml(file, user: user)
        imported << persona if persona
      end
    end

    imported.compact
  end

  # Import from markdown file (for files like architect.md, planner.md)
  def self.import_from_markdown(file_path, user: nil)
    return nil unless File.exist?(file_path)

    content = File.read(file_path)
    name = File.basename(file_path, ".md").downcase.gsub(/[^a-z0-9\-]/, "-")

    # Try to extract YAML frontmatter
    if content.start_with?("---")
      parts = content.split("---", 3)
      yaml_content = parts[1]
      markdown_content = parts[2]&.strip

      begin
        data = YAML.safe_load(yaml_content, permitted_classes: [Symbol])
        name = data["name"] if data["name"]
      rescue Psych::SyntaxError, Psych::BadAlias, StandardError
        markdown_content = content
      end
    else
      markdown_content = content
    end

    persona = find_or_initialize_by(name: name, user: user)
    persona.assign_attributes(
      description: "Imported from #{File.basename(file_path)}",
      model: "sonnet",
      project: "global",
      system_prompt: markdown_content,
      emoji: emoji_for_name(name),
      active: true
    )

    persona.save!
    persona
  rescue StandardError => e
    Rails.logger.error "Failed to import persona from #{file_path}: #{e.message}"
    nil
  end

  private

  def self.emoji_for_name(name)
    case name.to_s.downcase
    when /tech-lead|orchestrat/ then "🎯"
    when /code-review/ then "🔍"
    when /frontend/ then "🎨"
    when /backend/ then "⚙️"
    when /security/ then "🔒"
    when /research/ then "📚"
    when /network|ops/ then "🌐"
    when /whatsapp/ then "💬"
    when /dashboard/ then "📊"
    when /architect/ then "🏗️"
    when /planner/ then "📋"
    when /executor/ then "⚡"
    when /verifier/ then "✅"
    when /debug/ then "🐛"
    when /doc/ then "📝"
    when /build|error/ then "🔧"
    when /test|e2e/ then "🧪"
    when /refactor/ then "♻️"
    when /summar/ then "📄"
    else "🤖"
    end
  end
end
