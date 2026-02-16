# frozen_string_literal: true

class TaskActivity < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :task, inverse_of: :activities
  belongs_to :user, optional: true

  ACTIONS = %w[created updated moved auto_claimed auto_queued].freeze
  TRACKED_FIELDS = %w[name priority due_date].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :source, inclusion: { in: %w[web api system], allow_blank: true }
  validates :actor_type, inclusion: { in: %w[user agent system], allow_blank: true }
  validates :actor_name, length: { maximum: 200 }, allow_blank: true
  validates :actor_emoji, length: { maximum: 20 }, allow_blank: true
  validates :note, length: { maximum: 2000 }, allow_blank: true
  validates :field_name, length: { maximum: 100 }, allow_blank: true
  validates :old_value, length: { maximum: 1000 }, allow_blank: true
  validates :new_value, length: { maximum: 1000 }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record_creation(task, source: "web", actor_name: nil, actor_emoji: nil, note: nil)
    create!(
      task: task,
      user: task.user,
      action: "created",
      source: source,
      actor_type: source == "api" ? "agent" : "user",
      actor_name: actor_name,
      actor_emoji: actor_emoji,
      note: note
    )
  end

  def self.record_status_change(task, old_status:, new_status:, source: "web", actor_name: nil, actor_emoji: nil, note: nil)
    create!(
      task: task,
      user: Current.user,
      action: "moved",
      field_name: "status",
      old_value: old_status,
      new_value: new_status,
      source: source,
      actor_type: source == "api" ? "agent" : "user",
      actor_name: actor_name,
      actor_emoji: actor_emoji,
      note: note
    )
  end

  def self.record_changes(task, changes, source: "web", actor_name: nil, actor_emoji: nil, note: nil)
    TRACKED_FIELDS.each do |field|
      next unless changes.key?(field) || changes.key?(field.to_sym)

      old_val, new_val = changes[field] || changes[field.to_sym]
      create!(
        task: task,
        user: Current.user,
        action: "updated",
        field_name: field,
        old_value: format_value(field, old_val),
        new_value: format_value(field, new_val),
        source: source,
        actor_type: source == "api" ? "agent" : "user",
        actor_name: actor_name,
        actor_emoji: actor_emoji,
        note: note
      )
    end
  end

  def description
    case action
    when "created"
      source == "api" ? "Created via API" : "Created"
    when "moved"
      describe_move
    when "updated"
      describe_update
    when "auto_claimed"
      "🤖 Auto-claimed by agent"
    else
      action.humanize
    end
  end

  private

  def describe_move
    from_label = format_status(old_value)
    to_label = format_status(new_value)
    "Moved from #{from_label} to #{to_label}"
  end

  def describe_update
    field_label = field_name.humanize
    if old_value.blank?
      "Set #{field_label.downcase} to #{new_value}"
    elsif new_value.blank?
      "Removed #{field_label.downcase}"
    else
      "Changed #{field_label.downcase} from #{old_value} to #{new_value}"
    end
  end

  def format_status(status)
    case status
    when "inbox" then "Inbox"
    when "up_next" then "Up Next"
    when "in_progress" then "In Progress"
    when "in_review" then "In Review"
    when "done" then "Done"
    else status.to_s.titleize
    end
  end

  def self.format_value(field, value)
    return nil if value.nil?

    case field
    when "priority"
      Task.priorities.key(value)&.humanize || value.to_s
    when "due_date"
      value.is_a?(Date) ? value.strftime("%b %d, %Y") : value.to_s
    else
      value.to_s.truncate(50)
    end
  end
end
