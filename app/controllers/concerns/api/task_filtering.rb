# frozen_string_literal: true

# Concern that extracts task filtering and search logic from TasksController.
# Handles: board_id, status, blocked, tag, completed, priority, assigned, nightly, pagination.
#
# Usage:
#   class TasksController < ApplicationController
#     include Api::TaskFiltering
#   end
module Api
  module TaskFiltering
    extend ActiveSupport::Concern

    # Build a filtered, paginated tasks relation from request params.
    #
    # @param relation [ActiveRecord::Relation] base task relation
    # @param params [ActionController::Parameters] request params
    # @param default_includes [Array<Symbol>] default associations to eager load
    # @return [ActiveRecord::Relation] filtered and paginated tasks
    def filter_tasks(relation, params, default_includes: [:board, :agent_persona, :parent_task, :followup_task])
      tasks = relation.includes(default_includes)

      # Filter by board
      if params[:board_id].present?
        tasks = tasks.where(board_id: params[:board_id])
      end

      # Filter by status
      if params[:status].present? && relation.model.statuses.key?(params[:status])
        tasks = tasks.where(status: params[:status])
      end

      # Filter by blocked
      if params[:blocked].present?
        blocked = ActiveModel::Type::Boolean.new.cast(params[:blocked])
        tasks = tasks.where(blocked: blocked)
      end

      # Filter by tag (PostgreSQL array)
      if params[:tag].present?
        tasks = tasks.where("? = ANY(tags)", params[:tag])
      end

      # Filter by completed
      if params[:completed].present?
        completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
        tasks = tasks.where(completed: completed)
      end

      # Filter by priority
      if params[:priority].present? && relation.model.priorities.key?(params[:priority])
        tasks = tasks.where(priority: params[:priority])
      end

      # Filter by agent assignment
      if params[:assigned].present?
        assigned = ActiveModel::Type::Boolean.new.cast(params[:assigned])
        tasks = tasks.where(assigned_to_agent: assigned)
      end

      # Filter by nightly (Nightbeat) tasks
      if params[:nightly].present?
        nightly = ActiveModel::Type::Boolean.new.cast(params[:nightly])
        tasks = tasks.where(nightly: nightly)
      end

      # Filter by search query (title/description)
      if params[:q].present?
        search_term = "%#{params[:q]}%"
        tasks = tasks.where("name ILIKE :q OR description ILIKE :q", q: search_term)
      end

      # Order results
      tasks = order_tasks(tasks, params)

      # Pagination
      tasks = paginate_tasks(tasks, params)

      tasks
    end

    # Apply ordering based on params.
    #
    # @param tasks [ActiveRecord::Relation]
    # @param params [ActionController::Parameters]
    # @return [ActiveRecord::Relation]
    def order_tasks(tasks, params)
      if params[:assigned].present? && ActiveModel::Type::Boolean.new.cast(params[:assigned])
        tasks.order(assigned_at: :asc)
      elsif params[:order_by].present?
        case params[:order_by].to_sym
        when :created_at
          tasks.order(created_at: :desc)
        when :updated_at
          tasks.order(updated_at: :desc)
        when :priority
          tasks.order(priority: :desc, position: :asc)
        when :due_date
          tasks.order(due_date: :asc, position: :asc)
        else
          tasks.order(status: :asc, position: :asc)
        end
      else
        tasks.order(status: :asc, position: :asc)
      end
    end

    # Apply pagination based on params.
    #
    # @param tasks [ActiveRecord::Relation]
    # @param params [ActionController::Parameters]
    # @return [ActiveRecord::Relation]
    def paginate_tasks(tasks, params)
      page = [(params[:page] || 1).to_i, 1].max
      per_page = [(params[:per_page] || 50).to_i.clamp(1, 100), 100].min

      tasks.offset((page - 1) * per_page).limit(per_page)
    end

    # Build pagination metadata headers.
    #
    # @param tasks [ActiveRecord::Relation] paginated relation (before offset/limit for total)
    # @param page [Integer] current page
    # @param per_page [Integer] items per page
    # @return [Hash] header name => value
    def pagination_headers(tasks, page, per_page)
      total = tasks.count
      headers = {
        "X-Total-Count" => total.to_s,
        "X-Page" => page.to_s,
        "X-Per-Page" => per_page.to_s
      }
      headers["X-Next-Page"] = (page + 1).to_s if page * per_page < total
      headers
    end
  end
end
