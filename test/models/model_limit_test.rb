# frozen_string_literal: true

require "test_helper"

class ModelLimitTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    # Clear any existing model limits
    ModelLimit.where(user: @user).destroy_all
  end

  # --- Validations ---
  test "valid with required fields" do
    ml = ModelLimit.new(user: @user, name: "opus", limited: false)
    assert ml.valid?
  end

  test "requires name" do
    ml = ModelLimit.new(user: @user, name: nil)
    assert_not ml.valid?
  end

  test "validates name inclusion in MODELS" do
    ml = ModelLimit.new(user: @user, name: "gpt-99")
    assert_not ml.valid?
  end

  test "uniqueness scoped to user" do
    ModelLimit.create!(user: @user, name: "opus")
    ml2 = ModelLimit.new(user: @user, name: "opus")
    assert_not ml2.valid?
    assert_includes ml2.errors[:name], "has already been taken"
  end

  # --- Instance methods ---
  test "active_limit? true when limited and future reset" do
    ml = ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.from_now)
    assert ml.active_limit?
  end

  test "active_limit? false when limited but past reset" do
    ml = ModelLimit.create!(user: @user, name: "codex", limited: true, resets_at: 1.hour.ago)
    assert_not ml.active_limit?
  end

  test "active_limit? false when not limited" do
    ml = ModelLimit.create!(user: @user, name: "sonnet", limited: false)
    assert_not ml.active_limit?
  end

  test "clear! resets limit" do
    ml = ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.from_now, error_message: "rate limited")
    ml.clear!
    ml.reload
    assert_not ml.limited?
    assert_nil ml.resets_at
    assert_nil ml.error_message
  end

  test "set_limit! marks as limited" do
    ml = ModelLimit.create!(user: @user, name: "opus", limited: false)
    reset_time = 2.hours.from_now
    ml.set_limit!(error_message: "Rate limit exceeded", resets_at: reset_time)
    ml.reload
    assert ml.limited?
    assert_equal "Rate limit exceeded", ml.error_message
    assert_in_delta reset_time, ml.resets_at, 1.second
  end

  test "time_until_reset returns nil when no active limit" do
    ml = ModelLimit.new(resets_at: nil)
    assert_nil ml.time_until_reset
  end

  test "time_until_reset returns human-readable seconds" do
    ml = ModelLimit.new(resets_at: 30.seconds.from_now)
    result = ml.time_until_reset
    assert_match(/\d+s/, result)
  end

  test "time_until_reset returns human-readable minutes" do
    ml = ModelLimit.new(resets_at: 15.minutes.from_now)
    result = ml.time_until_reset
    assert_match(/\d+m/, result)
  end

  test "time_until_reset returns human-readable hours" do
    ml = ModelLimit.new(resets_at: 3.hours.from_now)
    result = ml.time_until_reset
    assert_match(/\d+h/, result)
  end

  # --- Class methods ---
  test "for_model finds or creates" do
    assert_difference "ModelLimit.count", 1 do
      ml = ModelLimit.for_model(@user, "opus")
      assert_equal "opus", ml.name
    end

    assert_no_difference "ModelLimit.count" do
      ml = ModelLimit.for_model(@user, "opus")
      assert_equal "opus", ml.name
    end
  end

  test "model_available? true when no limit exists" do
    assert ModelLimit.model_available?(@user, "opus")
  end

  test "model_available? true when limit expired" do
    ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.ago)
    assert ModelLimit.model_available?(@user, "opus")
  end

  test "model_available? false when actively limited" do
    ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.from_now)
    assert_not ModelLimit.model_available?(@user, "opus")
  end

  test "best_available_model returns requested if available" do
    model, note = ModelLimit.best_available_model(@user, "opus")
    assert_equal "opus", model
    assert_nil note
  end

  test "best_available_model falls back when requested is limited" do
    ModelLimit.create!(user: @user, name: "codex", limited: true, resets_at: 1.hour.from_now)
    model, note = ModelLimit.best_available_model(@user, "codex")
    assert_equal "opus", model # opus is next in priority
    assert_includes note, "rate-limited"
    assert_includes note, "Codex"
  end

  test "best_available_model returns first priority when all limited" do
    ModelLimit::MODEL_PRIORITY.each do |m|
      ModelLimit.create!(user: @user, name: m, limited: true, resets_at: 1.hour.from_now)
    end
    model, note = ModelLimit.best_available_model(@user)
    assert_equal "codex", model # first in priority
    assert_includes note, "All models rate-limited"
  end

  test "record_limit! creates limit with parsed reset time" do
    ml = ModelLimit.record_limit!(@user, "opus", "Rate limit exceeded. Retry after 3600 seconds")
    assert ml.limited?
    assert_in_delta 1.hour.from_now, ml.resets_at, 5.seconds
  end

  test "record_limit! parses ISO 8601 reset time" do
    future = (Time.current + 2.hours).utc.iso8601
    ml = ModelLimit.record_limit!(@user, "codex", "Resets at #{future}")
    assert ml.limited?
    assert_in_delta 2.hours.from_now, ml.resets_at, 10.seconds
  end

  test "record_limit! parses 'in ~N min' format" do
    ml = ModelLimit.record_limit!(@user, "sonnet", "Usage limit reached. Try again in ~60 min")
    assert ml.limited?
    assert_in_delta 1.hour.from_now, ml.resets_at, 10.seconds
  end

  test "clear_expired_limits! clears past limits" do
    ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.ago)
    ModelLimit.create!(user: @user, name: "codex", limited: true, resets_at: 1.hour.from_now)

    ModelLimit.clear_expired_limits!

    opus = ModelLimit.find_by(user: @user, name: "opus")
    codex = ModelLimit.find_by(user: @user, name: "codex")
    assert_not opus.limited?
    assert codex.limited?
  end

  # --- Scopes ---
  test "limited scope" do
    ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.from_now)
    ModelLimit.create!(user: @user, name: "codex", limited: false)
    assert_equal 1, ModelLimit.limited.count
  end

  test "active_limits scope" do
    ModelLimit.create!(user: @user, name: "opus", limited: true, resets_at: 1.hour.from_now)
    ModelLimit.create!(user: @user, name: "codex", limited: true, resets_at: 1.hour.ago)
    assert_equal 1, ModelLimit.active_limits.count
  end
end
