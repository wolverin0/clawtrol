# frozen_string_literal: true

# TaskImportService imports tasks from JSON export format.
#
# Usage:
#   importer = TaskImportService.new(user, board)
#   result = importer.import_json(json_string)
#   result.imported  # => 5
#   result.skipped   # => 1
#   result.errors    # => ["Row 3: Name can't be blank"]
#
class TaskImportService
  MAX_IMPORT_TASKS = 500

  # Fields that can be imported (subset of exportable for safety)
  IMPORTABLE_FIELDS = %w[
    name description status priority position
    tags model nightly blocked
    execution_plan validation_command
    pipeline_stage
  ].freeze

  Result = Struct.new(:imported, :skipped, :errors, :tasks, keyword_init: true)

  def initialize(user, board)
    @user = user
    @board = board
  end

  def import_json(json_string)
    data = parse_json(json_string)
    return Result.new(imported: 0, skipped: 0, errors: ["Invalid JSON format"], tasks: []) unless data

    task_list = data["tasks"] || data[:tasks]
    return Result.new(imported: 0, skipped: 0, errors: ["No tasks found in export"], tasks: []) unless task_list.is_a?(Array)

    if task_list.size > MAX_IMPORT_TASKS
      return Result.new(imported: 0, skipped: 0, errors: ["Too many tasks (max #{MAX_IMPORT_TASKS})"], tasks: [])
    end

    imported = []
    skipped = 0
    errors = []

    task_list.each_with_index do |task_data, idx|
      task_data = task_data.stringify_keys
      attrs = extract_importable_attrs(task_data)

      if attrs["name"].blank?
        errors << "Row #{idx + 1}: Name is blank, skipped"
        skipped += 1
        next
      end

      # Check for duplicate by name in target board
      if @board.tasks.exists?(name: attrs["name"], user: @user)
        errors << "Row #{idx + 1}: '#{attrs['name'].truncate(50)}' already exists, skipped"
        skipped += 1
        next
      end

      raw_status = attrs.delete("status")
      task = @user.tasks.new(attrs.merge(board: @board))
      task.status = normalize_status(raw_status)

      if task.save
        imported << task
      else
        errors << "Row #{idx + 1}: #{task.errors.full_messages.join(', ')}"
        skipped += 1
      end
    end

    Result.new(imported: imported.size, skipped: skipped, errors: errors, tasks: imported)
  end

  private

  def parse_json(json_string)
    JSON.parse(json_string)
  rescue JSON::ParserError
    nil
  end

  def extract_importable_attrs(task_data)
    attrs = {}
    IMPORTABLE_FIELDS.each do |field|
      value = task_data[field]
      next if value.nil?

      # Sanitize string values
      attrs[field] = value.is_a?(String) ? value.truncate(field == "description" ? 500_000 : 10_000) : value
    end
    attrs
  end

  def normalize_status(status)
    return :inbox unless status.present?
    Task.statuses.key?(status.to_s) ? status.to_s : "inbox"
  end
end
