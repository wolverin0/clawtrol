require "test_helper"

class NavigationHelperTest < ActiveSupport::TestCase
  class NavigationHelperHost
    include NavigationHelper

    attr_accessor :session, :current_user

    def initialize
      @session = {}
    end

    def boards_path
      "/boards"
    end

    def board_path(board)
      "/boards/#{board.id}"
    end
  end

  test "last_board_navigation_path falls back to boards path without session board id" do
    host = NavigationHelperHost.new

    assert_equal "/boards", host.last_board_navigation_path
  end

  test "last_board_navigation_path uses owned last board when present" do
    host = NavigationHelperHost.new
    user = users(:one)
    board = boards(:one)

    host.current_user = user
    host.session[:last_board_id] = board.id

    assert_equal "/boards/#{board.id}", host.last_board_navigation_path
  end

  test "last_board_navigation_path falls back when last board does not belong to current user" do
    host = NavigationHelperHost.new

    host.current_user = users(:one)
    host.session[:last_board_id] = boards(:two).id

    assert_equal "/boards", host.last_board_navigation_path
  end
end
