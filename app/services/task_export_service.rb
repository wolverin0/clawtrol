# frozen_string_literal: true

require "csv"

# Exports tasks for a user in JSON or CSV format.
# Supports filtering by board, statuses, tags, and archived state.
#
# Usage:
#   exporter = TaskExportService.new(user, board_id: 2, statuses: ["done"], tag: "bug")
#   exporter.to_json  # => JSON string
#   exporter.to_csv   # => CSV string
class TaskExportService
  EXPORT_FIELDS = %i[
    id name description status priority model
    board_id tags
    blocked completed nightly recurring assigned_to_agent
    agent_session_id pipeline_stage
    validation_command validation_status
    due_date completed_at created_at updated_at
  ].freeze

  attr_reader :user, :options

  def initialize(user, board_id: nil, statuses: nil, tag: nil, include_archived: false)
    @user = user
    @options = {
      board_id: board_id,
      statuses: Array(statuses).reject(&:blank?),
      tag: tag,
      include_archived: include_archived
    }
  end

  def tasks
    @tasks ||= build_query
  end

  def to_json(_opts = nil)
    {
      exported_at: Time.current.iso8601,
      count: tasks.size,
      tasks: tasks.map { |t| serialize(t) }
    }.to_json
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << csv_headers
      tasks.each { |t| csv << csv_row(t) }
    end
  end

  private

  def build_query
    scope = user.tasks.includes(:board)

    if options[:board_id].present?
      scope = scope.where(board_id: options[:board_id])
    end

    if options[:statuses].any?
      valid_statuses = options[:statuses].select { |s| Task.statuses.key?(s) }
      scope = scope.where(status: valid_statuses) if valid_statuses.any?
    end

    unless options[:include_archived]
      scope = scope.where.not(status: :archived)
    end

    if options[:tag].present?
      scope = scope.where("? = ANY(tags)", options[:tag])
    end

    scope.order(status: :asc, position: :asc)
  end

  def serialize(task)
    result = {}
    EXPORT_FIELDS.each do |field|
      value = task.try(field)
      result[field] = value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) ? value.iso8601(3) : value
    end
    result[:board_name] = task.board&.name
    result
  end

  def csv_headers
    EXPORT_FIELDS.map(&:to_s) + ["board_name"]
  end

  def csv_row(task)
    EXPORT_FIELDS.map do |field|
      value = task.try(field)
      case value
      when Time, ActiveSupport::TimeWithZone
        value.iso8601
      when Array
        value.join(", ")
      else
        value
      end
    end + [task.board&.name]
  end
end
