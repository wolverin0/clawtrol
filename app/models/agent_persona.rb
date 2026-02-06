class AgentPersona < ApplicationRecord
  belongs_to :user, optional: true  # nil = shared/system persona
  has_many :tasks, dependent: :nullify

  # Model options (same as Task)
  MODELS = %w[opus codex gemini glm sonnet].freeze
  TIERS = %w[strategic-reasoning fast-coding research operations].freeze
  
  # Default tools available
  DEFAULT_TOOLS = %w[Read Write Edit exec web_search web_fetch browser nodes message].freeze

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "already exists for this user" }
  validates :model, inclusion: { in: MODELS, allow_blank: true }
  validates :fallback_model, inclusion: { in: MODELS, allow_blank: true }
  validates :tier, inclusion: { in: TIERS, allow_blank: true }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_tier, ->(tier) { where(tier: tier) }
  scope :by_project, ->(project) { where(project: project) }
  scope :global, -> { where(project: 'global') }
  scope :for_user, ->(user) { where(user_id: [nil, user&.id]) }

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
  def tools_list
    case tools
    when Array then tools
    when String then tools.split(/,\s*/)
    else []
    end
  end

  # Tier badge color
  def tier_color
    case tier
    when 'strategic-reasoning' then 'purple'
    when 'fast-coding' then 'blue'
    when 'research' then 'green'
    when 'operations' then 'orange'
    else 'gray'
    end
  end

  # Model badge color
  def model_color
    case model
    when 'opus' then 'purple'
    when 'codex' then 'blue'
    when 'gemini' then 'emerald'
    when 'glm' then 'amber'
    when 'sonnet' then 'orange'
    else 'gray'
    end
  end

  # Import from YAML file
  def self.import_from_yaml(file_path, user: nil)
    return nil unless File.exist?(file_path)

    content = File.read(file_path)
    
    # Split YAML frontmatter from markdown content
    if content.start_with?('---')
      parts = content.split('---', 3)
      yaml_content = parts[1]
      markdown_content = parts[2]&.strip
    else
      yaml_content = content
      markdown_content = nil
    end

    data = YAML.safe_load(yaml_content, permitted_classes: [Symbol])
    return nil unless data

    persona = find_or_initialize_by(name: data['name'], user: user)
    persona.assign_attributes(
      description: data['description'],
      model: data['model'] || 'sonnet',
      fallback_model: data['fallback'],
      tier: data['tier'],
      project: data['project'] || 'global',
      tools: data['tools'] || [],
      system_prompt: markdown_content,
      active: true
    )
    
    # Auto-assign emoji based on name
    persona.emoji = emoji_for_name(data['name']) unless persona.emoji.present? && persona.emoji != '🤖'
    
    persona.save!
    persona
  rescue => e
    Rails.logger.error "Failed to import persona from #{file_path}: #{e.message}"
    nil
  end

  # Import all personas from a directory
  def self.import_from_directory(dir_path, user: nil)
    imported = []
    
    # Import from root .yaml files
    Dir.glob(File.join(dir_path, '*.yaml')).each do |file|
      next if File.basename(file) == 'registry.yaml'
      persona = import_from_yaml(file, user: user)
      imported << persona if persona
    end

    # Import from .md files
    Dir.glob(File.join(dir_path, '*.md')).each do |file|
      next if File.basename(file).downcase == 'readme.md'
      next if File.basename(file).upcase.start_with?('SPAWN')
      persona = import_from_markdown(file, user: user)
      imported << persona if persona
    end

    # Import from subdirectories
    %w[global projects].each do |subdir|
      subdir_path = File.join(dir_path, subdir)
      next unless Dir.exist?(subdir_path)
      
      Dir.glob(File.join(subdir_path, '*.yaml')).each do |file|
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
    name = File.basename(file_path, '.md').downcase.gsub(/[^a-z0-9\-]/, '-')
    
    # Try to extract YAML frontmatter
    if content.start_with?('---')
      parts = content.split('---', 3)
      yaml_content = parts[1]
      markdown_content = parts[2]&.strip
      
      begin
        data = YAML.safe_load(yaml_content, permitted_classes: [Symbol])
        name = data['name'] if data['name']
      rescue
        markdown_content = content
      end
    else
      markdown_content = content
    end

    persona = find_or_initialize_by(name: name, user: user)
    persona.assign_attributes(
      description: "Imported from #{File.basename(file_path)}",
      model: 'sonnet',
      project: 'global',
      system_prompt: markdown_content,
      emoji: emoji_for_name(name),
      active: true
    )
    
    persona.save!
    persona
  rescue => e
    Rails.logger.error "Failed to import persona from #{file_path}: #{e.message}"
    nil
  end

  private

  def self.emoji_for_name(name)
    case name.to_s.downcase
    when /tech-lead|orchestrat/ then '🎯'
    when /code-review/ then '🔍'
    when /frontend/ then '🎨'
    when /backend/ then '⚙️'
    when /security/ then '🔒'
    when /research/ then '📚'
    when /network|ops/ then '🌐'
    when /whatsapp/ then '💬'
    when /dashboard/ then '📊'
    when /architect/ then '🏗️'
    when /planner/ then '📋'
    when /executor/ then '⚡'
    when /verifier/ then '✅'
    when /debug/ then '🐛'
    when /doc/ then '📝'
    when /build|error/ then '🔧'
    when /test|e2e/ then '🧪'
    when /refactor/ then '♻️'
    when /summar/ then '📄'
    else '🤖'
    end
  end
end
