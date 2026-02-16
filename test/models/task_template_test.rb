# frozen_string_literal: true

require "test_helper"

class TaskTemplateTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
  end

  # === Validations ===

  test "name is required" do
    template = TaskTemplate.new(slug: "test")
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "slug is required" do
    template = TaskTemplate.new(name: "Test")
    assert_not template.valid?
    assert_includes template.errors[:slug], "can't be blank"
  end

  test "slug format must be lowercase alphanumeric with hyphens/underscores" do
    valid_slugs = %w[test test-123 test_abc a b]
    valid_slugs.each do |slug|
      template = TaskTemplate.new(name: "Test", slug: slug)
      assert template.valid?, "Slug #{slug} should be valid"
    end

    invalid_slugs = ["TEST", "Test", "test_ABC", "UPPERCASE", "with spaces"]
    invalid_slugs.each do |slug|
      template = TaskTemplate.new(name: "Test", slug: slug)
      assert_not template.valid?, "Slug #{slug} should be invalid"
    end
  end

  test "slug is unique per user" do
    template = TaskTemplate.create!(name: "Test", slug: "test", user: @user)
    duplicate = TaskTemplate.new(name: "Test 2", slug: "test", user: @user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "same slug allowed for different users" do
    template = TaskTemplate.create!(name: "Test", slug: "test", user: @user)
    other_user = users(:one)
    other = TaskTemplate.new(name: "Other", slug: "test", user: other_user)
    assert other.valid?
  end

  test "global templates have unique slug globally" do
    template = TaskTemplate.create!(name: "Global", slug: "global-test", global: true)
    duplicate = TaskTemplate.new(name: "Duplicate", slug: "global-test", global: true)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "global and user templates can share slug" do
    template = TaskTemplate.create!(name: "Global", slug: "shared", global: true)
    user_template = TaskTemplate.new(name: "User", slug: "shared", user: @user)
    assert user_template.valid?
  end

  test "model must be valid" do
    template = TaskTemplate.new(name: "Test", slug: "test", model: "invalid_model")
    assert_not template.valid?
    assert_includes template.errors[:model], "is not included in the list"
  end

  test "model can be nil or blank" do
    template = TaskTemplate.new(name: "Test", slug: "test", model: nil)
    assert template.valid?

    template = TaskTemplate.new(name: "Test", slug: "test", model: "")
    assert template.valid?
  end

  test "priority must be 0-3" do
    invalid_priorities = [-1, 4, 10]
    invalid_priorities.each do |p|
      template = TaskTemplate.new(name: "Test", slug: "test", priority: p)
      assert_not template.valid?, "Priority #{p} should be invalid"
    end

    valid_priorities = [0, 1, 2, 3, nil]
    valid_priorities.each do |p|
      template = TaskTemplate.new(name: "Test", slug: "test", priority: p)
      assert template.valid?, "Priority #{p} should be valid"
    end
  end

  test "validation_command must be safe" do
    # Unsafe commands
    unsafe = TaskTemplate.new(
      name: "Test",
      slug: "test",
      validation_command: "bin/rails test; rm -rf /"
    )
    assert_not unsafe.valid?
    assert unsafe.errors[:validation_command].any? { |e| e.include?("unsafe shell metacharacters") }

    unsafe2 = TaskTemplate.new(
      name: "Test",
      slug: "test2",
      validation_command: "echo $(whoami)"
    )
    assert_not unsafe2.valid?

    # Safe commands
    safe = TaskTemplate.new(
      name: "Test",
      slug: "test3",
      validation_command: "bin/rails test"
    )
    assert safe.valid?
  end

  test "validation_command must start with allowed prefix" do
    template = TaskTemplate.new(
      name: "Test",
      slug: "test",
      validation_command: "python manage.py test"
    )
    assert_not template.valid?
    assert_includes template.errors[:validation_command], "must start with an allowed prefix"
  end

  # === Associations ===

  test "belongs to user (optional)" do
    template = TaskTemplate.create!(name: "Test", slug: "test")
    assert_nil template.user

    template_with_user = TaskTemplate.create!(name: "Test2", slug: "test2", user: @user)
    assert_equal @user, template_with_user.user
  end

  # === Scopes ===

  test "for_user scope includes global and user-specific templates" do
    global = TaskTemplate.create!(name: "Global", slug: "global-for-user", global: true)
    user_template = TaskTemplate.create!(name: "User", slug: "user-for-user", user: @user)

    results = TaskTemplate.for_user(@user)
    assert_includes results, global
    assert_includes results, user_template
  end

  test "global_templates scope" do
    global = TaskTemplate.create!(name: "Global", slug: "global-scope", global: true)
    user_template = TaskTemplate.create!(name: "User", slug: "user-scope", user: @user)

    assert_includes TaskTemplate.global_templates, global
    assert_not_includes TaskTemplate.global_templates, user_template
  end

  test "user_templates scope" do
    user_template = TaskTemplate.create!(name: "User", slug: "user-scope-2", user: @user)
    global = TaskTemplate.create!(name: "Global", slug: "global-scope-2", global: true)

    assert_includes TaskTemplate.user_templates(@user), user_template
    assert_not_includes TaskTemplate.user_templates(@user), global
  end

  test "ordered scope sorts global first then by name" do
    user_t = TaskTemplate.create!(name: "User Z", slug: "user-z", user: @user)
    global = TaskTemplate.create!(name: "Global A", slug: "global-a", global: true)
    user_t2 = TaskTemplate.create!(name: "User A", slug: "user-a", user: @user)
    global2 = TaskTemplate.create!(name: "Global Z", slug: "global-z", global: true)

    ordered = TaskTemplate.ordered.where(id: [user_t.id, global.id, user_t2.id, global2.id]).to_a

    # Global templates first (desc), then alphabetical
    assert_equal global, ordered[0]
    assert_equal global2, ordered[1]
    assert_equal user_t2, ordered[2]
    assert_equal user_t, ordered[3]
  end

  # === Class Methods ===

  test "find_for_user prefers user-specific over global" do
    global = TaskTemplate.create!(
      name: "Global Bug",
      slug: "bug-find",
      global: true
    )
    user_template = TaskTemplate.create!(
      name: "User Bug",
      slug: "bug-find",
      user: @user
    )

    found = TaskTemplate.find_for_user("bug-find", @user)
    assert_equal user_template, found
  end

  test "find_for_user falls back to global" do
    global = TaskTemplate.create!(
      name: "Global Only",
      slug: "global-only",
      global: true
    )

    found = TaskTemplate.find_for_user("global-only", @user)
    assert_equal global, found
  end

  test "find_for_user returns nil for non-existent" do
    found = TaskTemplate.find_for_user("non-existent", @user)
    assert_nil found
  end

  test "create_defaults! creates 5 default templates" do
    TaskTemplate.where(user: @user).destroy_all

    TaskTemplate.create_defaults!(user: @user)

    assert_equal 5, TaskTemplate.where(user: @user).count
    assert TaskTemplate.exists?(slug: "review", user: @user)
    assert TaskTemplate.exists?(slug: "bug", user: @user)
    assert TaskTemplate.exists?(slug: "doc", user: @user)
    assert TaskTemplate.exists?(slug: "test", user: @user)
    assert TaskTemplate.exists?(slug: "research", user: @user)
  end

  test "create_defaults! can create global templates" do
    TaskTemplate.where(global: true).destroy_all

    TaskTemplate.create_defaults!(global: true)

    assert_equal 5, TaskTemplate.where(global: true).count
  end

  # === Instance Methods ===

  test "display_name includes icon when present" do
    template = TaskTemplate.new(name: "Test", icon: "🔍")
    assert_equal "🔍 Test", template.display_name
  end

  test "display_name without icon" do
    template = TaskTemplate.new(name: "Test")
    assert_equal "Test", template.display_name
  end

  test "to_task_attributes builds correct hash" do
    template = TaskTemplate.new(
      name: "Bug",
      icon: "🐛",
      priority: 2,
      model: "opus",
      description_template: "## Bug\n\n**Desc**",
      validation_command: "bin/rails test"
    )

    attrs = template.to_task_attributes("Fix login")

    assert_equal "🐛 Fix login", attrs[:name]
    assert_equal 2, attrs[:priority]
    assert_equal "opus", attrs[:model]
    assert_equal "## Bug\n\n**Desc**", attrs[:description]
    assert_equal "bin/rails test", attrs[:validation_command]
  end

  test "to_task_attributes without optional fields" do
    template = TaskTemplate.new(name: "Simple")

    attrs = template.to_task_attributes("Simple task")

    assert_equal "Simple task", attrs[:name]
    assert_nil attrs[:description]
    assert_nil attrs[:validation_command]
  end
end
