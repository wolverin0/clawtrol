class Board < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :position, presence: true

  before_create :set_position

  # Default scope orders by position
  default_scope { order(position: :asc) }

  # Available board colors (Tailwind-compatible)
  COLORS = %w[gray red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose].freeze

  # Available board icons (emojis)
  DEFAULT_ICONS = %w[📋 📝 🎯 🚀 💡 🔧 📊 🎨 📚 🏠 💼 🎮 🎵 📸 ✨ 🦞 🌐].freeze

  # Auto-claim rate limit: 1 per minute per board
  AUTO_CLAIM_RATE_LIMIT_SECONDS = 60

  # Check if this board aggregates tasks from all boards
  def aggregator?
    is_aggregator?
  end

  # Auto-claim methods
  def auto_claim_enabled?
    auto_claim_enabled
  end

  def can_auto_claim?
    return false unless auto_claim_enabled?
    return true if last_auto_claim_at.nil?

    last_auto_claim_at < AUTO_CLAIM_RATE_LIMIT_SECONDS.seconds.ago
  end

  def task_matches_auto_claim?(task)
    return false unless auto_claim_enabled?

    has_tags_filter = auto_claim_tags.present?
    has_prefix_filter = auto_claim_prefix.present?

    # If neither filter is set, claim all tasks
    return true unless has_tags_filter || has_prefix_filter

    # Check each active filter
    tags_match = has_tags_filter && (task.tags.to_a & auto_claim_tags).any?
    prefix_match = has_prefix_filter && task.name.to_s.start_with?(auto_claim_prefix)

    # At least one active filter must match
    tags_match || prefix_match
  end

  def record_auto_claim!
    update_column(:last_auto_claim_at, Time.current)
  end

  # Get all tasks for this user (for aggregator boards)
  def all_user_tasks
    Task.where(user_id: user_id)
  end

  def self.create_onboarding_for(user)
    board = user.boards.create!(
      name: "Getting Started",
      icon: "🚀",
      color: "blue"
    )

    tasks = [
      {
        name: "👋 Welcome to ClawDeck!",
        description: "Your mission control for AI agents. Drag tasks between columns, and your agent picks up what you assign. Think of it as a shared kanban with your AI coworker.",
        status: "inbox",
        position: 0
      },
      {
        name: "🔗 Connect your agent",
        description: "Go to Settings → copy the integration prompt → paste it into your agent's config. Once connected, you'll see your agent appear in the header.",
        status: "inbox",
        position: 1
      },
      {
        name: "✅ Assign your first task",
        description: "Create a task, then right-click → \"Assign to Agent\". Your agent will pick it up and start working. Watch the activity feed for updates!",
        status: "inbox",
        position: 2
      },
      {
        name: "💡 Example: Research task",
        description: "\"Research the top 5 competitors to [product] and summarize their pricing models.\" — Great for agents with web access.",
        status: "inbox",
        position: 3
      },
      {
        name: "💡 Example: Code task",
        description: "\"Add a dark mode toggle to the settings page. Use Tailwind classes.\" — Perfect for coding agents.",
        status: "inbox",
        position: 4
      },
      {
        name: "💡 Example: Writing task",
        description: "\"Draft a welcome email for new users. Keep it short, friendly, 3 paragraphs max.\" — Works with any agent.",
        status: "inbox",
        position: 5
      },
      {
        name: "🎯 Try it yourself!",
        description: "Delete these cards and create your first real task. Be specific — your agent works best with clear instructions.",
        status: "up_next",
        position: 0
      }
    ]

    tasks.each do |task_attrs|
      board.tasks.create!(task_attrs.merge(user: user))
    end

    board
  end

  private

  def set_position
    return if position.present? && position > 0

    max_position = user.boards.unscoped.where(user_id: user_id).maximum(:position) || 0
    self.position = max_position + 1
  end
end
