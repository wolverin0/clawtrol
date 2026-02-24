require "test_helper"

class NavigationHelperTest < ActiveSupport::TestCase
  class NavigationHelperHost
    include NavigationHelper

    attr_accessor :session, :current_user

    def initialize
      @session = {}
    end

    def boards_path = "/boards"
    def board_path(board)
      board_id = board.respond_to?(:id) ? board.id : board
      "/boards/#{board_id}"
    end
    def workflows_path = "/workflows"
    def factory_path = "/factory"
    def nightshift_path = "/nightshift"
    def sessions_explorer_path = "/sessions"
    def nodes_path = "/nodes"
    def skill_manager_path = "/skills"
    def agent_personas_path = "/agent_personas"
    def roster_agent_personas_path = "/agent_personas/roster"
    def agent_config_path = "/agent_config"
    def analytics_path = "/analytics"
    def tokens_path = "/tokens"
    def outputs_path = "/outputs"
    def dm_scope_audit_path = "/self_audit"
    def showcases_path = "/showcases"
    def command_path = "/command"
    def terminal_path = "/terminal"
    def saved_links_path = "/saved_links"
    def learning_proposals_path = "/learning_proposals"
    def webhook_mappings_path = "/webhook_mappings"
    def gateway_config_path = "/gateway_config"
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

  test "primary_navigation board item uses last board navigation path" do
    host = NavigationHelperHost.new
    host.current_user = users(:one)
    host.session[:last_board_id] = boards(:one).id

    board_item = host.primary_navigation
      .find { |category| category[:id] == :tasks }[:items]
      .find { |item| item[:label] == "Board" }

    assert_equal "/boards/#{boards(:one).id}", board_item[:url]
  end

  test "primary_navigation board item falls back to boards path for unowned board" do
    host = NavigationHelperHost.new
    host.current_user = users(:one)
    host.session[:last_board_id] = boards(:two).id

    board_item = host.primary_navigation
      .find { |category| category[:id] == :tasks }[:items]
      .find { |item| item[:label] == "Board" }

    assert_equal "/boards", board_item[:url]
  end
end
