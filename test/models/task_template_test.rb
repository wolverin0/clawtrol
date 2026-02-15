# frozen_string_literal: true

require "test_helper"

class TaskTemplateTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = TaskTemplate.new(
      slug: "deploy",
      name: "Deploy Task",
      icon: "🚀",
      model: "opus",
      priority: 2,
      description_template: "## Deploy\n\n**Target:**\n",
      validation_command: "bin/rails test",
      user: @user
    )
  end

  # --- Validations ---

  test "valid template saves" do
    assert @template.valid?
  end

  test "requires name" do
    @template.name = nil
    assert_not @template.valid?
    assert_includes @template.errors[:name], "can't be blank"
  end

  test "requires slug" do
    @template.slug = nil
    assert_not @template.valid?
    assert_includes @template.errors[:slug], "can't be blank"
  end

  test "slug format: lowercase alphanumeric with hyphens and underscores" do
    @template.slug = "valid-slug_123"
    assert @template.valid?

    @template.slug = "Invalid Slug!"
    assert_not @template.valid?
    assert_includes @template.errors[:slug].join, "only allows lowercase"
  end

  test "slug uniqueness scoped to user" do
    @template.save!
    dup = TaskTemplate.new(slug: "deploy", name: "Another Deploy", user: @user)
    assert_not dup.valid?
  end

  test "same slug allowed for different users" do
    @template.save!
    other_user = users(:two)
    other = TaskTemplate.new(slug: "deploy", name: "Deploy", user: other_user)
    assert other.valid?
  end

  test "global slug uniqueness" do
    global = TaskTemplate.new(slug: "global-test", name: "Global", global: true)
    global.save!
    dup = TaskTemplate.new(slug: "global-test", name: "Global Dup", global: true)
    assert_not dup.valid?
  end

  test "model must be valid when present" do
    @template.model = "nonexistent"
    assert_not @template.valid?
  end

  test "model allows blank" do
    @template.model = ""
    assert @template.valid?
  end

  test "priority must be 0..3" do
    @template.priority = 4
    assert_not @template.valid?

    @template.priority = -1
    assert_not @template.valid?

    @template.priority = 0
    assert @template.valid?

    @template.priority = 3
    assert @template.valid?
  end

  test "validation_command rejects unsafe metacharacters" do
    @template.validation_command = "bin/rails test; rm -rf /"
    assert_not @template.valid?
    assert_includes @template.errors[:validation_command].join, "unsafe"
  end

  test "validation_command rejects disallowed prefixes" do
    @template.validation_command = "curl http://evil.com"
    assert_not @template.valid?
    assert_includes @template.errors[:validation_command].join, "allowed prefix"
  end

  test "validation_command accepts safe commands" do
    @template.validation_command = "bin/rails test"
    assert @template.valid?

    @template.validation_command = "npm test"
    assert @template.valid?
  end

  # --- Class methods ---

  test "find_for_user prefers user-specific over global" do
    user_template = task_templates(:review)
    global_template = task_templates(:global_bug)

    # User template should be found for user one
    found = TaskTemplate.find_for_user("review", @user)
    assert_equal user_template, found

    # Global template found for any user
    found_global = TaskTemplate.find_for_user("bug", @user)
    assert_equal global_template, found_global
  end

  test "find_for_user returns nil for nonexistent slug" do
    assert_nil TaskTemplate.find_for_user("nonexistent", @user)
  end

  # --- Instance methods ---

  test "display_name includes icon when present" do
    assert_equal "🚀 Deploy Task", @template.display_name
  end

  test "display_name without icon" do
    @template.icon = nil
    assert_equal "Deploy Task", @template.display_name
  end

  test "to_task_attributes builds correct hash" do
    attrs = @template.to_task_attributes("Fix login")
    assert_equal "🚀 Fix login", attrs[:name]
    assert_equal 2, attrs[:priority]
    assert_equal "opus", attrs[:model]
    assert_includes attrs[:description], "Deploy"
    assert_equal "bin/rails test", attrs[:validation_command]
  end

  test "to_task_attributes without icon" do
    @template.icon = nil
    attrs = @template.to_task_attributes("Fix login")
    assert_equal "Fix login", attrs[:name]
  end

  # --- Scopes ---

  test "for_user includes user and global templates" do
    templates = TaskTemplate.for_user(@user)
    assert templates.any? { |t| t.user_id == @user.id }
    assert templates.any?(&:global?)
  end
end
