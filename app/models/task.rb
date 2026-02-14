class Task < ApplicationRecord
  include Task::Broadcasting
  include Task::Recurring
  include Task::TranscriptParsing
  include Task::DependencyManagement
  include Task::AgentIntegration

  belongs_to :user
  belongs_to :board
  belongs_to :agent_persona, optional: true
  belongs_to :parent_task, class_name: "Task", optional: true
  belongs_to :followup_task, class_name: "Task", optional: true
  has_many :activities, class_name: "TaskActivity", dependent: :destroy
  has_many :child_tasks, class_name: "Task", foreign_key: :parent_task_id, dependent: :nullify
  has_one :source_task, class_name: "Task", foreign_key: :followup_task_id
  has_many :notifications, dependent: :destroy
  has_many :token_usages, dependent: :destroy
  has_many :task_diffs, dependent: :destroy

  has_many :task_runs, dependent: :destroy
  has_many :agent_transcripts, dependent: :nullify
  has_many :runner_leases, dependent: :destroy

  # Task dependencies (blocking relationships)
  has_many :task_dependencies, dependent: :destroy
  has_many :dependencies, through: :task_dependencies, source: :depends_on
  has_many :inverse_dependencies, class_name: "TaskDependency", foreign_key: :depends_on_id, dependent: :destroy
  has_many :dependents, through: :inverse_dependencies, source: :task

  enum :priority, { none: 0, low: 1, medium: 2, high: 3 }, default: :none, prefix: true
  enum :status, { inbox: 0, up_next: 1, in_progress: 2, in_review: 3, done: 4, archived: 5 }, default: :inbox

  # Kanban paging
  KANBAN_PER_COLUMN_ITEMS = 25

  # Model options for agent LLM selection
  MODELS = %w[opus codex gemini glm sonnet].freeze
  DEFAULT_MODEL = "opus".freeze

  # Map ClawTrol task.model -> OpenClaw sessions_spawn model alias.
  OPENCLAW_MODEL_ALIASES = {
    "gemini" => "gemini3"
  }.freeze

  # Review types
  REVIEW_TYPES = %w[command debate].freeze
  REVIEW_STATUSES = %w[pending running passed failed].freeze

  # Debate styles for review
  DEBATE_STYLES = %w[quick thorough adversarial collaborative].freeze
  DEBATE_MODELS = %w[gemini claude glm].freeze

  # Pipeline stages
  PIPELINE_STAGES = %w[triaged context_ready routed executing verifying completed failed].freeze

  # Security: allowed validation command prefixes
  ALLOWED_VALIDATION_PREFIXES = %w[
    bin/rails
    bundle\ exec
    npm
    yarn
    make
    pytest
    rspec
    ruby
    node
    bash\ bin/
    sh\ bin/
    ./bin/
  ].freeze

  UNSAFE_COMMAND_PATTERN = /[;|&$`\\!\(\)\{\}<>]|(\$\()|(\|\|)|(&&)/

  validates :name, presence: true
  validates :priority, inclusion: { in: priorities.keys }
  validates :status, inclusion: { in: statuses.keys }
  validates :model, inclusion: { in: MODELS }, allow_nil: true, allow_blank: true
  validates :recurrence_rule, inclusion: { in: %w[daily weekly monthly] }, allow_nil: true, allow_blank: true
  validates :pipeline_stage, inclusion: { in: PIPELINE_STAGES }, allow_nil: true, allow_blank: true
  validate :validation_command_is_safe, if: -> { validation_command.present? }

  attr_accessor :activity_source, :actor_name, :actor_emoji, :activity_note

  after_create :record_creation_activity
  after_update :record_update_activities
  after_update :create_status_notification, if: :saved_change_to_status?
  after_save :enqueue_pipeline_processing, if: :should_trigger_pipeline?

  before_create :set_position
  before_save :sync_completed_with_status
  before_update :track_completion_time, if: :will_save_change_to_status?

  scope :incomplete, -> { where(completed: false).order(position: :asc) }
  scope :completed, -> { where(completed: true).order(Arel.sql("#{table_name}.completed_at DESC")) }
  scope :assigned_to_agent, -> { where(assigned_to_agent: true).order(assigned_at: :asc) }
  scope :unassigned, -> { where(assigned_to_agent: false) }
  scope :recurring_templates, -> { where(recurring: true, parent_task_id: nil) }
  scope :due_for_recurrence, -> { recurring_templates.where("next_recurrence_at <= ?", Time.current) }
  scope :nightly, -> { where(nightly: true) }
  scope :errored, -> { where.not(error_at: nil) }
  scope :not_errored, -> { where(error_at: nil) }
  scope :archived, -> { where(status: :archived) }
  scope :not_archived, -> { where.not(status: :archived) }
  scope :missing_agent_output, -> {
    where(status: :done)
      .where("assigned_to_agent = :yes OR agent_session_id IS NOT NULL OR assigned_at IS NOT NULL", yes: true)
      .where("description IS NULL OR description NOT LIKE ?", "%## Agent Output%")
  }

  # Pipeline scopes
  scope :pipeline_enabled, -> { where(pipeline_enabled: true) }
  scope :pipeline_pending, -> { pipeline_enabled.where(pipeline_stage: nil) }
  scope :pipeline_triaged, -> { pipeline_enabled.where(pipeline_stage: "triaged") }
  scope :pipeline_routed, -> { pipeline_enabled.where(pipeline_stage: "routed") }

  scope :ordered_for_column, ->(column_status) {
    case column_status.to_s
    when "in_review"
      order(updated_at: :desc, id: :desc)
    when "done"
      order(Arel.sql("#{table_name}.id DESC"))
    else
      order(position: :asc, id: :asc)
    end
  }

  def openclaw_spawn_model
    OPENCLAW_MODEL_ALIASES.fetch(model.to_s, model.presence || DEFAULT_MODEL)
  end

  # Pipeline helpers
  def pipeline_active?
    pipeline_enabled? && pipeline_stage.present?
  end

  def pipeline_ready?
    pipeline_stage == "routed" && routed_model.present? && compiled_prompt.present?
  end

  def advance_pipeline_stage!(new_stage, log_entry = {})
    entry = log_entry.merge(stage: new_stage, at: Time.current.iso8601)
    current_log = Array(pipeline_log)
    update_columns(
      pipeline_stage: new_stage,
      pipeline_log: current_log.push(entry)
    )
  end

  private

  def validation_command_is_safe
    cmd = validation_command.to_s.strip

    if cmd.match?(UNSAFE_COMMAND_PATTERN)
      errors.add(:validation_command, "contains unsafe shell metacharacters (no ;, |, &, $, backticks allowed)")
      return
    end

    unless ALLOWED_VALIDATION_PREFIXES.any? { |prefix| cmd.start_with?(prefix) }
      errors.add(:validation_command, "must start with an allowed prefix: #{ALLOWED_VALIDATION_PREFIXES.join(', ')}")
    end
  end

  def set_position
    return if position.present?

    max_position = board.tasks.where(status: status).maximum(:position) || 0
    self.position = max_position + 1
  end

  def sync_completed_with_status
    self.completed = (status == "done")
  end

  def track_completion_time
    if status == "done"
      self.completed_at = Time.current
    elsif status == "archived"
      self.archived_at = Time.current
    else
      self.completed_at = nil
    end
  end

  def record_creation_activity
    TaskActivity.record_creation(self, source: activity_source || "web", actor_name: actor_name, actor_emoji: actor_emoji, note: activity_note)
  end

  def record_update_activities
    source = activity_source || "web"

    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      TaskActivity.record_status_change(self, old_status: old_status, new_status: new_status, source: source, actor_name: actor_name, actor_emoji: actor_emoji, note: activity_note)
    end

    tracked_changes = saved_changes.slice(*TaskActivity::TRACKED_FIELDS)
    TaskActivity.record_changes(self, tracked_changes, source: source, actor_name: actor_name, actor_emoji: actor_emoji, note: activity_note) if tracked_changes.any?
  end

  def create_status_notification
    return unless user
    old_status, new_status = saved_change_to_status
    Notification.create_for_status_change(self, old_status, new_status)
  end

  def should_trigger_pipeline?
    return false unless pipeline_enabled?
    return false if pipeline_stage.present?
    return false unless saved_change_to_status?

    _old, new_status = saved_change_to_status
    %w[up_next in_progress].include?(new_status)
  end

  def enqueue_pipeline_processing
    PipelineProcessorJob.perform_later(id)
  end
end
