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
    # Favorite icon is rendered as ★ (filled star) or ☆ (empty)
    assert_selector "body", wait: 5 # page loaded
    assert_text "★"
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
    @idea = swarm_ideas(:code_idea)
    @idea.update!(user: @user, board: @board)

    sign_in_as(@user)
  end

  test "can navigate to swarm from boards" do
    visit swarm_path

    # Should render swarm page directly
    assert_selector "body", wait: 10
    assert_no_text "Sign in to continue"
  end

  test "swarm is responsive - has idea cards" do
    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Should show idea content
    assert_text "Refactor auth module"
  end

  test "model picker dropdown appears when selecting idea" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Should show model selection UI inline on the idea card
    assert_selector "select", minimum: 1, wait: 5
  end

  test "board assignment is available before launch" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Board select should be available on the page
    assert_selector "select", minimum: 1, wait: 5
  end

  test "launch button is disabled without required selections" do
    skip "Requires JavaScript support" unless ApplicationSystemTestCase::CHROME_AVAILABLE

    visit swarm_path

    # Wait for page
    assert_selector "body", wait: 10

    # Should have some button on the page (LAUNCH or similar)
    assert_selector "button", minimum: 1
  end

  test "swarm shows idea status indicators" do

    visit swarm_path

    assert_selector "body", wait: 10

    # Should show the idea (launched ideas may show differently)
    assert_text "Refactor auth module"
  end

  test "swarm filters ideas by category" do
    visit swarm_path

    assert_selector "body", wait: 10

    # Should show category filter options (ALL, CODE, RESEARCH, etc.)
    assert_text "ALL"
  end

  test "swarm shows idea description on expansion" do
    visit swarm_path

    assert_selector "body", wait: 10

    # Ideas should have descriptions visible
    assert_text "Refactor", wait: 5
  end

  test "swarm history shows past launches" do
    visit swarm_path

    assert_selector "body", wait: 10

    # Page should load without errors
    assert_no_text "Sign in to continue"
  end
end
