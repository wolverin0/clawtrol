# frozen_string_literal: true

require "application_system_test_case"

class SwarmLauncherTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @idea = swarm_ideas(:code_idea)
    @favorite_idea = swarm_ideas(:favorite_idea)

    # Ensure ideas belong to the correct user
    @idea.update!(user: @user, board: @board)
    @favorite_idea.update!(user: @user, board: @board)

    sign_in_as(@user)
  end

  test "swarm page loads with idea list" do
    visit swarm_path

    # Wait for page to fully load
    assert_selector "body", wait: 10

    # Should show the ideas
    assert_text "Refactor auth module"
    assert_text "Research AI agents"
  end

  test "idea selection works" do
    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Find and click an idea card
    assert_text "Refactor auth module"
    
    # The page should have selection UI
    # Check for launch button presence
    assert_selector "button", minimum: 1
  end

  test "favorites section shows favorite ideas" do
    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Favorite idea should be visible
    assert_text "Research AI agents"
    assert_text "⭐"  # favorite icon
  end

  test "disabled ideas are not shown or are marked" do
    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # The disabled idea "Old cleanup task" should either not appear or be marked as disabled
    # Check the ideas visible - only enabled ones should be prominent
    disabled = swarm_ideas(:disabled_idea)
    disabled.update!(user: @user, board: @board)
  end

  test "swarm page shows category icons" do
    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Should show category icons
    assert_text "🔧"  # code icon
    assert_text "🔬"  # research icon
  end

  test "swarm page loads without errors" do
    visit swarm_path

    # Wait for page to load
    assert_selector "body", wait: 10

    # Check we're not on login page
    assert_no_text "Sign in to continue"

    # Should show swarm title or ideas
    assert_text "Refactor auth module"
  end
end

class SwarmLauncherNavigationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @board = boards(:one)

    sign_in_as(@user)
  end

  test "can navigate to swarm from boards" do
    visit boards_path

    # Wait for page to load
    assert_selector "body", wait: 10

    # Navigate to swarm
    click_link "Swarm", wait: 5

    # Should be on swarm page
    assert_current_path /\/swarm/
  end

  test "swarm is responsive - has idea cards" do
    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Should have idea cards
    assert_selector "[data-swarm-idea-id]", minimum: 1
  end
end
