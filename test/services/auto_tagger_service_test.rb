# frozen_string_literal: true

require "test_helper"

class AutoTaggerServiceTest < ActiveSupport::TestCase
  # --- .tag ---
  test "returns empty for blank input" do
    assert_equal [], AutoTaggerService.tag(nil)
    assert_equal [], AutoTaggerService.tag("")
  end

  test "detects security keywords" do
    tags = AutoTaggerService.tag("Fix SQL injection in login")
    assert_includes tags, "security"
    assert_includes tags, "sql-injection"
    assert_includes tags, "bug"
  end

  test "detects XSS" do
    tags = AutoTaggerService.tag("Prevent XSS in user input")
    assert_includes tags, "security"
    assert_includes tags, "xss"
  end

  test "detects bug/fix" do
    tags = AutoTaggerService.tag("Fix broken pagination")
    assert_includes tags, "bug"
    assert_includes tags, "fix"
  end

  test "detects performance keywords" do
    tags = AutoTaggerService.tag("Fix N+1 queries in dashboard")
    assert_includes tags, "performance"
  end

  test "detects refactor" do
    tags = AutoTaggerService.tag("Extract concern from controllers")
    assert_includes tags, "code-quality"
    assert_includes tags, "refactor"
  end

  test "detects frontend" do
    tags = AutoTaggerService.tag("Add responsive CSS for mobile")
    assert_includes tags, "frontend"
    assert_includes tags, "css"
    assert_includes tags, "responsive"
  end

  test "detects backend/api" do
    tags = AutoTaggerService.tag("Add new API endpoint for tasks")
    assert_includes tags, "backend"
    assert_includes tags, "api"
  end

  test "detects infrastructure" do
    tags = AutoTaggerService.tag("Deploy Docker containers")
    assert_includes tags, "infrastructure"
    assert_includes tags, "deploy"
    assert_includes tags, "docker"
  end

  test "detects network/ISP" do
    tags = AutoTaggerService.tag("Configure MikroTik firewall rules")
    assert_includes tags, "network"
    assert_includes tags, "mikrotik"
  end

  test "detects research" do
    tags = AutoTaggerService.tag("Research alternative auth libraries")
    assert_includes tags, "research"
  end

  test "case insensitive" do
    tags = AutoTaggerService.tag("FIX SQL INJECTION BUG")
    assert_includes tags, "security"
    assert_includes tags, "bug"
  end

  test "deduplicates tags" do
    tags = AutoTaggerService.tag("security fix for XSS security issue")
    assert_equal tags.uniq, tags
  end

  test "respects max_tags" do
    tags = AutoTaggerService.tag("Fix SQL injection XSS CSRF bug in slow API endpoint for MikroTik router", max_tags: 3)
    assert tags.length <= 3
  end

  test "combines title and description text" do
    tags = AutoTaggerService.tag("Fix login Security issue with SQL injection in the auth module")
    assert_includes tags, "security"
    assert_includes tags, "sql-injection"
    assert_includes tags, "auth"
  end

  # --- .suggest_model ---
  test "suggests gemini for research" do
    assert_equal "gemini", AutoTaggerService.suggest_model(%w[research])
  end

  test "returns nil for frontend tags" do
    assert_nil AutoTaggerService.suggest_model(%w[frontend css])
  end

  test "returns nil for empty tags" do
    assert_nil AutoTaggerService.suggest_model([])
    assert_nil AutoTaggerService.suggest_model(nil)
  end

  test "returns nil for generic backend tags" do
    assert_nil AutoTaggerService.suggest_model(%w[backend api])
  end

  # --- .suggest_priority ---
  test "suggests high for security" do
    assert_equal "high", AutoTaggerService.suggest_priority(%w[security xss])
  end

  test "suggests high for bugs" do
    assert_equal "high", AutoTaggerService.suggest_priority(%w[bug fix])
  end

  test "suggests medium for performance" do
    assert_equal "medium", AutoTaggerService.suggest_priority(%w[performance])
  end

  test "returns nil for non-priority tags" do
    assert_nil AutoTaggerService.suggest_priority(%w[frontend ui])
  end
end
