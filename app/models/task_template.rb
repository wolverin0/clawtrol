class TaskTemplate < ApplicationRecord
  belongs_to :user, optional: true

  # Same model options as Task
  MODELS = Task::MODELS

  # Default templates (slug -> config)
  DEFAULTS = {
    "review" => {
      name: "Code Review",
      icon: "🔍",
      model: "opus",
      validation_command: "bin/rails test",
      priority: 2,
      description_template: "## Code Review Task\n\n**What to review:**\n"
    },
    "bug" => {
      name: "Bug Fix",
      icon: "🐛",
      model: "sonnet",
      priority: 2,
      description_template: "## Bug Fix\n\n**Problem:**\n\n**Expected behavior:**\n\n**Steps to reproduce:**\n"
    },
    "doc" => {
      name: "Documentation",
      icon: "📝",
      model: "glm",
      priority: 1,
      description_template: "## Documentation Task\n\n**What to document:**\n"
    },
    "test" => {
      name: "Write Tests",
      icon: "🧪",
      model: "codex",
      validation_command: "bin/rails test",
      priority: 2,
      description_template: "## Testing Task\n\n**What to test:**\n"
    },
    "research" => {
      name: "Research",
      icon: "🔬",
      model: "gemini",
      priority: 1,
      description_template: "## Research Task\n\n**Topic:**\n\n**Questions to answer:**\n"
    }
  }.freeze

  validates :name, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9_-]+\z/, message: "only allows lowercase letters, numbers, hyphens, and underscores" }
  validates :slug, uniqueness: { scope: :user_id }, if: -> { user_id.present? }
  validates :slug, uniqueness: true, if: -> { global? }
  validates :model, inclusion: { in: MODELS }, allow_nil: true, allow_blank: true
  validates :priority, inclusion: { in: 0..3 }, allow_nil: true
  validate :validation_command_is_safe, if: -> { validation_command.present? }

  scope :for_user, ->(user) { where(user_id: [user.id, nil]) }
  scope :global_templates, -> { where(global: true) }
  scope :user_templates, ->(user) { where(user_id: user.id) }
  scope :ordered, -> { order(global: :desc, name: :asc) }

  # Find template by slug, preferring user-specific over global
  def self.find_for_user(slug, user)
    where(slug: slug, user_id: user.id).first || where(slug: slug, global: true).first
  end

  # Create default templates for new users or as global templates
  def self.create_defaults!(user: nil, global: false)
    DEFAULTS.each do |slug, config|
      create!(
        slug: slug,
        name: config[:name],
        icon: config[:icon],
        model: config[:model],
        priority: config[:priority] || 0,
        validation_command: config[:validation_command],
        description_template: config[:description_template],
        user: user,
        global: global
      )
    end
  end

  # Display name with icon
  def display_name
    icon.present? ? "#{icon} #{name}" : name
  end

  # Build task attributes from this template
  def to_task_attributes(task_name)
    attrs = {
      name: icon.present? ? "#{icon} #{task_name}" : task_name,
      priority: priority || 0,
      model: model
    }
    attrs[:description] = description_template if description_template.present?
    attrs[:validation_command] = validation_command if validation_command.present?
    attrs
  end

  private

  # Same validation as Task model for safety
  def validation_command_is_safe
    cmd = validation_command.to_s.strip
    unsafe_pattern = /[;|&$`\\!\(\)\{\}<>]|(\$\()|(\|\|)|(&&)/

    if cmd.match?(unsafe_pattern)
      errors.add(:validation_command, "contains unsafe shell metacharacters")
      return
    end

    allowed_prefixes = Task::ALLOWED_VALIDATION_PREFIXES
    unless allowed_prefixes.any? { |prefix| cmd.start_with?(prefix) }
      errors.add(:validation_command, "must start with an allowed prefix")
    end
  end
end
