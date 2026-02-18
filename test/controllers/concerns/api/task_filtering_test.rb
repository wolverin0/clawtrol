# frozen_string_literal: true

require "test_helper"

class Api::TaskFilteringTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = @user.tasks.create!(
      name: "Test Task",
      board: @board,
      status: :inbox,
      position: 1
    )
  end

  class MockController
    include Api::TaskFiltering

    attr_reader :response

    def initialize
      @response = MockResponse.new
    end

    class MockResponse
      attr_accessor :headers

      def initialize
        @headers = {}
      end
    end
  end

  test "filter_tasks filters by board_id" do
    controller = MockController.new
    other_board = boards(:two)

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(board_id: @board.id))

    assert_includes tasks, @task
    refute_includes tasks, other_board.tasks.first
  end

  test "filter_tasks filters by status" do
    controller = MockController.new

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(status: "inbox"))

    assert_includes tasks, @task
  end

  test "filter_tasks filters by priority" do
    controller = MockController.new
    high_priority = @user.tasks.create!(
      name: "High Priority",
      board: @board,
      status: :inbox,
      position: 2,
      priority: 3
    )

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(priority: "high"))

    assert_includes tasks, high_priority
    # Original task has default priority (medium)
    # Only high priority should be returned
  end

  test "filter_tasks orders by assigned_at when assigned filter is true" do
    controller = MockController.new

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(assigned: "true"))

    # Should have assigned_at ordering
    assert tasks.order_values.any?
  end

  test "filter_tasks orders by status and position by default" do
    controller = MockController.new

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new({}))

    # Should have status and position ordering
    order_sql = tasks.order_values.map { |o| o.respond_to?(:expression) ? o.expression.to_sql : o.to_sql }.join(", ")
    assert_match(/status/i, order_sql)
    assert_match(/position/i, order_sql)
  end

  test "paginate_tasks applies limit and offset" do
    controller = MockController.new
    @user.tasks.create!(name: "Task 2", board: @board, status: :inbox, position: 3)
    @user.tasks.create!(name: "Task 3", board: @board, status: :inbox, position: 4)

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(page: "2", per_page: "1"))

    assert_equal 1, tasks.count
  end

  test "paginate_tasks clamps per_page to max 100" do
    controller = MockController.new

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(per_page: "500"))

    # Check the limit value from the relation
    assert_equal 100, tasks.limit_value
  end

  test "order_tasks supports custom order_by" do
    controller = MockController.new

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(order_by: "created_at"))

    assert tasks.order_values.any?
  end

  test "pagination_headers returns correct headers" do
    controller = MockController.new
    headers = controller.pagination_headers(Task.all, 1, 10)

    assert_equal Task.count.to_s, headers["X-Total-Count"]
    assert_equal "1", headers["X-Page"]
    assert_equal "10", headers["X-Per-Page"]
  end

  test "filter_tasks with search query" do
    controller = MockController.new

    tasks = controller.filter_tasks(Task.all, ActionController::Parameters.new(q: "Test"))

    assert_includes tasks, @task
  end
end
