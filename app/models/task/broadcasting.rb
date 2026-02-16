# frozen_string_literal: true

module Task::Broadcasting
  extend ActiveSupport::Concern

  included do
    # Store activity_source before commit so it survives the transaction
    before_save :store_activity_source_for_broadcast

    # Real-time broadcasts to user's board (only for API/background changes)
    # Skip broadcasts when activity_source is "web" since the UI already handles it
    after_create_commit :broadcast_create
    after_update_commit :broadcast_update
    after_destroy_commit :broadcast_destroy
  end

  private

  def store_activity_source_for_broadcast
    @stored_activity_source = activity_source
  end

  def skip_broadcast?
    @stored_activity_source == "web" || activity_source == "web"
  end

  # Turbo Streams broadcasts for real-time updates
  # Note: We reload with includes to avoid N+1 queries when rendering partials
  def broadcast_create
    if skip_broadcast?
      # Still notify WebSocket clients (other tabs/devices) even when the change came from the web UI.
      KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "create")
      return
    end

    # Reload with associations to avoid N+1 when rendering the partial
    task_with_associations = Task.includes(:board, :user, :agent_persona).find(id)

    if auto_sorted_column?(status)
      broadcast_sorted_column(status)
    else
      broadcast_to_board(
        action: :prepend,
        target: "column-#{status}",
        partial: "boards/task_card",
        locals: { task: task_with_associations }
      )
    end

    broadcast_column_count(status)

    # Also broadcast via ActionCable KanbanChannel for WebSocket clients
    KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "create")
  end

  def broadcast_update
    if skip_broadcast?
      # Still notify WebSocket clients (other tabs/devices) even when the change came from the web UI.
      if saved_change_to_status?
        old_s, new_s = saved_change_to_status
        KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "update", old_status: old_s, new_status: new_s)
      else
        KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "update")
      end
      return
    end

    # Reload with associations to avoid N+1 when rendering the partial
    task_with_associations = Task.includes(:board, :user, :agent_persona).find(id)

    # If status changed, handle move between columns
    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      # Remove from old column
      broadcast_to_board(action: :remove, target: "task_#{id}")

      if auto_sorted_column?(new_status)
        broadcast_sorted_column(new_status)
      else
        broadcast_to_board(
          action: :prepend,
          target: "column-#{new_status}",
          partial: "boards/task_card",
          locals: { task: task_with_associations }
        )
      end

      broadcast_sorted_column(old_status) if auto_sorted_column?(old_status)
      broadcast_column_count(old_status)
      broadcast_column_count(new_status)
    else
      # For auto-sorted columns, replace the whole list to preserve deterministic order.
      if auto_sorted_column?(status)
        broadcast_sorted_column(status)
      else
        broadcast_to_board(
          action: :replace,
          target: "task_#{id}",
          partial: "boards/task_card",
          locals: { task: task_with_associations }
        )
      end
    end

    # Also broadcast via ActionCable KanbanChannel for WebSocket clients
    # Include status transition for sound effects
    if saved_change_to_status?
      old_s, new_s = saved_change_to_status
      KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "update", old_status: old_s, new_status: new_s)
    else
      KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "update")
    end

    # Broadcast agent activity updates when agent-related fields change
    if saved_change_to_agent_session_id? || saved_change_to_status? || saved_change_to_agent_claimed_at?
      AgentActivityChannel.broadcast_status(id, status)
    end
  end

  def broadcast_destroy
    if skip_broadcast?
      # Still notify WebSocket clients (other tabs/devices) even when the change came from the web UI.
      KanbanChannel.broadcast_refresh(board_id, task_id: id, action: "destroy")
      return
    end

    # Cache values before they become inaccessible
    cached_board_id = board_id
    cached_status = status
    cached_id = id
    stream = "board_#{cached_board_id}"

    Turbo::StreamsChannel.broadcast_action_to(stream, action: :remove, target: "task_#{cached_id}")

    # Board can already be gone when tasks are destroyed as part of board destruction.
    if (board = Board.find_by(id: cached_board_id))
      count = board.tasks.where(status: cached_status).count
      Turbo::StreamsChannel.broadcast_action_to(
        stream,
        action: :replace,
        target: "column-#{cached_status}-count",
        html: %(<span id="column-#{cached_status}-count" class="ml-auto text-xs text-content-secondary bg-bg-elevated px-1.5 py-0.5 rounded">#{count}</span>)
      )
    end

    # Also broadcast via ActionCable KanbanChannel for WebSocket clients
    KanbanChannel.broadcast_refresh(cached_board_id, task_id: cached_id, action: "destroy")
  end

  def broadcast_column_count(column_status)
    count = board.tasks.where(status: column_status).count
    broadcast_to_board(
      action: :replace,
      target: "column-#{column_status}-count",
      html: %(<span id="column-#{column_status}-count" class="ml-auto text-xs text-content-secondary bg-bg-elevated px-1.5 py-0.5 rounded">#{count}</span>)
    )
  end

  def auto_sorted_column?(column_status)
    %w[in_review done].include?(column_status.to_s)
  end

  def broadcast_sorted_column(column_status)
    scope = board.tasks
      .not_archived
      .where(status: column_status)
      .includes(:board, :user, :agent_persona)
      .ordered_for_column(column_status)

    # Keep kanban columns lightweight: only render first page, and let infinite scroll load more.
    per_column = self.class::KANBAN_PER_COLUMN_ITEMS
    first_page_plus_one = scope.limit(per_column + 1).to_a
    tasks = first_page_plus_one.first(per_column)
    has_more = first_page_plus_one.length > per_column

    broadcast_to_board(
      action: :replace,
      target: "column-#{column_status}",
      partial: "boards/column_tasks",
      locals: { status: column_status, tasks: tasks, board: board, has_more: has_more }
    )
  end

  def board_stream_name
    "board_#{board_id}"
  end

  def broadcast_to_board(action:, target:, **options)
    Turbo::StreamsChannel.broadcast_action_to(board_stream_name, action: action, target: target, **options)
  end
end
