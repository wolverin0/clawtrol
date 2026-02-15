# frozen_string_literal: true

class Task < ApplicationRecord
  include Task::Broadcasting
  include Task::Recurring
  include Task::TranscriptParsing
  include Task::DependencyManagement
  include Task::AgentIntegration

  # strict_loading helps detect N+1 queries in development/test
  strict_loading :n_plus_one

  belongs_to :user
  belongs_to :board, counter_cache: true, inverse_of: :tasks
  belongs_to :agent_persona, optional: true, inverse_of: :tasks
  belongs_to :parent_task, class_name: "Task", optional: true
  belongs_to :followup_task, class_name: "Task", optional: true
  has_many :activities, class_name: "TaskActivity", dependent: :destroy, inverse_of: :activities
  has_many :child_tasks, class_name: "Task", foreign_key: :parent_task_id, dependent: :nullify
  has_one :source_task, class_name: "Task", foreign_key: :followup_task_id
  has_many :notifications, dependent: :destroy, inverse_of: :task
  has_many :token_usages, dependent: :destroy, inverse_of: :task
  has_many :task_diffs, dependent: :destroy, inverse_of: :task
  has_many :agent_test_recordings, dependent: :nullify

  has_many :task_runs, dependent: :destroy, inverse_of: :task
  has_many :agent_transcripts, dependent: :nullify, inverse_of: :task
  has_many :runner_leases, dependent: :destroy, inverse_of: :task
  has_many :agent_messages, dependent: :destroy, inverse_of: :task

  # Enforce eager loading to prevent N+1 queries
  strict_loading :n_plus_one

  # Task dependencies (blocking relationships)
  has_many :task_dependencies, dependent: :destroy, inverse_of: :task
  has_many :dependencies, through: :task_dependencies, source: :depends_on
  has_many :inverse_dependencies, class_name: "TaskDependency", foreign_key: :depends_on_id, dependent: :destroy
  has_many :dependents, through: :inverse_dependencies, source: :task

  enum :priority, { none: 0, low: 1, medium: 2, high: 3 }, default: :none, prefix: true
  enum :status, { inbox: 0, up_next: 1, in_progress: 2, in_review: 3, done: 4, archived: 5 }, default: :inbox
  # Pipeline stages - production pipeline services use these values.
  PIPELINE_STAGES = %w[unstarted triaged context_ready routed executing verifying completed failed].freeze

  # NOTE: pipeline_stage is a string column in production (not integer).
  # Use string-backed enum to match the DB schema.
  enum :pipeline_stage, {
    unstarted: "unstarted",
    triaged: "triaged",
    context_ready: "context_ready",
    routed: "routed",
    executing: "executing",
    verifying: "verifying",
    completed: "completed",
    failed: "failed"
  }, default: :unstarted, prefix: :pipeline

  # Pipeline stage transition rules: each stage lists valid predecessors
  PIPELINE_TRANSITIONS = {
    "unstarted"     => [],
    "triaged"       => %w[unstarted failed],
    "context_ready" => %w[triaged],
    "routed"        => %w[context_ready],
    "executing"     => %w[routed],
    "verifying"     => %w[executing],
    "completed"     => %w[verifying executing],
    "failed"        => %w[unstarted triaged context_ready routed executing verifying]
  }.freeze

  # Kanban paging
  KANBAN_PER_COLUMN_ITEMS = 25

  # Model options for agent LLM selection
  # NOTE: These values are the *ClawTrol* UI/task-level model choices.
  # They intentionally stay small and stable (opus/codex/gemini/glm/sonnet).
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

  # Security: allowed validation command prefixes to prevent arbitrary command execution
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

  # Security: pattern to reject shell metacharacters in validation commands
  UNSAFE_COMMAND_PATTERN = /[;|&$`\\!\(\)\{\}<>]|(\$\()|(\|\|)|(&&)/

  validates :name, presence: true, length: { maximum: 500 }
  validates :priority, inclusion: { in: priorities.keys }
  validates :status, inclusion: { in: statuses.keys }
  validates :pipeline_stage, inclusion: { in: pipeline_stages.keys }
  validates :model, inclusion: { in: MODELS }, allow_nil: true, allow_blank: true
  validates :recurrence_rule, inclusion: { in: %w[daily weekly monthly] }, allow_nil: true, allow_blank: true
  validates :description, length: { maximum: 500_000 }, allow_nil: true
  validates :execution_plan, length: { maximum: 100_000 }, allow_nil: true
  validates :error_message, length: { maximum: 50_000 }, allow_nil: true
  validates :validation_command, length: { maximum: 1_000 }, allow_nil: true
  validate :validation_command_is_safe, if: -> { validation_command.present? }
  validate :pipeline_stage_transition_is_valid, if: :will_save_change_to_pipeline_stage?
  validate :dispatched_requires_plan, if: :will_save_change_to_pipeline_stage?

  # Activity tracking - must be declared before callbacks that use it
  attr_accessor :activity_source, :actor_name, :actor_emoji, :activity_note

  after_create :record_creation_activity
  after_update :record_update_activities
  after_update :create_status_notification, if: :saved_change_to_status?

  # Position management
  before_create :set_position
  before_save :sync_completed_with_status
  before_update :track_completion_time, if: :will_save_change_to_status?

  # Order incomplete tasks by position, completed tasks by completion time (most recent first)
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
scope :pipeline_pending, -> { pipeline_enabled.where(pipeline_stage: [nil, "", "unstarted"]) }
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

  # Returns the model identifier that OpenClaw should receive for sessions_spawn.
  def openclaw_spawn_model
    OPENCLAW_MODEL_ALIASES.fetch(model.to_s, model.presence || DEFAULT_MODEL)
  end

# Pipeline helpers
def pipeline_active?
  pipeline_enabled? && pipeline_stage.present? && !pipeline_stage.in?(%w[completed failed])
end

def pipeline_ready?
  pipeline_stage == "routed" && routed_model.present? && compiled_prompt.present?
end

def advance_pipeline_stage!(new_stage, log_entry = nil)
  updates = { pipeline_stage: new_stage }
  if log_entry
    current_log = pipeline_log || []
    updates[:pipeline_log] = current_log + [log_entry.merge(timestamp: Time.current.iso8601)]
  end
  update!(updates)
end


  private

  # Pipeline: executing stage should have compiled_prompt
  def dispatched_requires_plan
    return unless pipeline_stage == "executing"
    return if compiled_prompt.present? || !pipeline_enabled?

    errors.add(:pipeline_stage, "cannot move to executing without a compiled_prompt when pipeline is enabled")
  end

  # Pipeline: validate stage transitions follow the defined order
  def pipeline_stage_transition_is_valid
    return if new_record? # Allow any initial stage on creation

    old_stage = pipeline_stage_was.to_s
    new_stage = pipeline_stage.to_s

    return if old_stage == new_stage # No change

    valid_predecessors = PIPELINE_TRANSITIONS[new_stage]
    return if valid_predecessors.nil? # Unknown stage — inclusion validation catches this

    unless valid_predecessors.include?(old_stage)
      errors.add(:pipeline_stage, "cannot transition from '#{old_stage}' to '#{new_stage}'. Valid predecessors: #{valid_predecessors.join(', ')}")
    end
  end

  # Security: validate that validation_command is safe to execute
  def validation_command_is_safe
    cmd = validation_command.to_s.strip

    # Reject shell metacharacters
    if cmd.match?(UNSAFE_COMMAND_PATTERN)
      errors.add(:validation_command, "contains unsafe shell metacharacters (no ;, |, &, $, backticks allowed)")
      return
    end

    # Must start with an allowed prefix
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

  # Track completion and archival timestamps.
  # Clears stale timestamps when moving out of terminal states
  # to prevent stale data on unarchived/reopened tasks.
  def track_completion_time
    if status == "done"
      self.completed_at = Time.current
      self.archived_at = nil
    elsif status == "archived"
      self.archived_at = Time.current
    else
      self.completed_at = nil
      self.archived_at = nil
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

  # Create notification on status change
  def create_status_notification
    return unless user
    old_status, new_status = saved_change_to_status
    Notification.create_for_status_change(self, old_status, new_status)
  end
end
