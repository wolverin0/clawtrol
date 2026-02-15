# frozen_string_literal: true

require "test_helper"

class EmojiShortcodeNormalizerTest < ActiveSupport::TestCase
  test "returns blank string unchanged" do
    assert_equal "", EmojiShortcodeNormalizer.normalize("")
    assert_equal "", EmojiShortcodeNormalizer.normalize("  ")
    assert_equal "", EmojiShortcodeNormalizer.normalize(nil)
  end

  test "converts known shortcode to emoji" do
    assert_equal "📟", EmojiShortcodeNormalizer.normalize(":pager:")
  end

  test "shortcode matching is case-insensitive" do
    assert_equal "📟", EmojiShortcodeNormalizer.normalize(":PAGER:")
    assert_equal "📟", EmojiShortcodeNormalizer.normalize(":Pager:")
  end

  test "returns unknown shortcodes unchanged" do
    assert_equal ":unknown:", EmojiShortcodeNormalizer.normalize(":unknown:")
    assert_equal ":rocket:", EmojiShortcodeNormalizer.normalize(":rocket:")
  end

  test "returns regular emoji unchanged" do
    assert_equal "🤖", EmojiShortcodeNormalizer.normalize("🤖")
    assert_equal "📋", EmojiShortcodeNormalizer.normalize("📋")
  end

  test "returns plain text unchanged" do
    assert_equal "hello", EmojiShortcodeNormalizer.normalize("hello")
    assert_equal "Otacon", EmojiShortcodeNormalizer.normalize("Otacon")
  end

  test "strips leading and trailing whitespace" do
    assert_equal "📟", EmojiShortcodeNormalizer.normalize("  :pager:  ")
    assert_equal "🤖", EmojiShortcodeNormalizer.normalize(" 🤖 ")
  end

  test "does not match partial shortcodes" do
    assert_equal ":pager", EmojiShortcodeNormalizer.normalize(":pager")
    assert_equal "pager:", EmojiShortcodeNormalizer.normalize("pager:")
    assert_equal "hello :pager: world", EmojiShortcodeNormalizer.normalize("hello :pager: world")
  end

  test "handles integer input" do
    assert_equal "42", EmojiShortcodeNormalizer.normalize(42)
  end
end
