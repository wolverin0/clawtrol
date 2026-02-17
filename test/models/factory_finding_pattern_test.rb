require "test_helper"

class FactoryFindingPatternTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "test-pattern-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @loop = FactoryLoop.create!(
      name: "Pattern Loop",
      slug: "pattern-loop-#{SecureRandom.hex(4)}",
      interval_ms: 60_000,
      model: "flash",
      status: "idle",
      user: @user
    )

    @pattern = FactoryFindingPattern.create!(
      factory_loop: @loop,
      pattern_hash: "abc123",
      description: "A repeated finding",
      category: "testing"
    )
  end

  test "dismiss increments dismiss_count" do
    assert_equal 0, @pattern.dismiss_count

    @pattern.dismiss!

    assert_equal 1, @pattern.reload.dismiss_count
    assert_not @pattern.suppressed?
  end

  test "dismiss suppresses pattern after second dismissal" do
    @pattern.dismiss!
    @pattern.dismiss!

    @pattern.reload
    assert_equal 2, @pattern.dismiss_count
    assert @pattern.suppressed?
  end
end
