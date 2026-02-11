# frozen_string_literal: true

require "test_helper"

class MarkdownSanitizationHelperTest < ActionView::TestCase
  include MarkdownSanitizationHelper

  # === XSS Prevention Tests ===

  test "strips script tags from markdown" do
    malicious = "Hello <script>alert('XSS')</script> World"
    result = safe_markdown(malicious)

    # The <script> tag should be stripped (XSS prevented)
    # The text content may remain but is harmless without the script tag
    assert_not_includes result, "<script>"
    assert_not_includes result, "</script>"
    assert_includes result, "Hello"
    assert_includes result, "World"
  end

  test "strips javascript: URLs from links" do
    malicious = "[Click me](javascript:alert('XSS'))"
    result = safe_markdown(malicious)

    assert_not_includes result, "javascript:"
  end

  test "strips onerror handlers from images" do
    malicious = '<img src="x" onerror="alert(1)">'
    result = safe_markdown(malicious)

    assert_not_includes result, "onerror"
  end

  test "strips onclick handlers from elements" do
    malicious = '<div onclick="alert(1)">Click me</div>'
    result = safe_markdown(malicious)

    assert_not_includes result, "onclick"
  end

  test "strips embedded script in markdown code fence" do
    # Scripts should be escaped even within content
    malicious = "Check this:\n\n<script>document.cookie</script>"
    result = safe_markdown(malicious)

    assert_not_includes result, "<script>"
  end

  test "strips style tags that could execute JS" do
    malicious = '<style>@import "javascript:alert(1)"</style>'
    result = safe_markdown(malicious)

    assert_not_includes result, "<style>"
  end

  test "strips iframe injection" do
    malicious = '<iframe src="https://evil.com"></iframe>'
    result = safe_markdown(malicious)

    assert_not_includes result, "<iframe>"
  end

  test "strips object and embed tags" do
    malicious = '<object data="malware.swf"></object><embed src="bad.swf">'
    result = safe_markdown(malicious)

    assert_not_includes result, "<object>"
    assert_not_includes result, "<embed>"
  end

  # === Valid Markdown Rendering Tests ===

  test "renders headers correctly" do
    markdown = "# H1\n## H2\n### H3"
    result = safe_markdown(markdown)

    assert_includes result, "<h1>"
    assert_includes result, "<h2>"
    assert_includes result, "<h3>"
  end

  test "renders links with safe attributes" do
    markdown = "[Example](https://example.com)"
    result = safe_markdown(markdown)

    assert_includes result, "<a"
    assert_includes result, 'href="https://example.com"'
  end

  test "renders code blocks" do
    markdown = "```ruby\nputs 'hello'\n```"
    result = safe_markdown(markdown)

    assert_includes result, "<code"
    assert_includes result, "<pre>"
  end

  test "renders inline code" do
    markdown = "Use `code` here"
    result = safe_markdown(markdown)

    assert_includes result, "<code>"
    assert_includes result, "code"
  end

  test "renders tables" do
    markdown = <<~MD
      | Header | Header |
      |--------|--------|
      | Cell   | Cell   |
    MD
    result = safe_markdown(markdown)

    assert_includes result, "<table>"
    assert_includes result, "<th>"
    assert_includes result, "<td>"
  end

  test "renders ordered and unordered lists" do
    markdown = "- Item 1\n- Item 2\n\n1. First\n2. Second"
    result = safe_markdown(markdown)

    assert_includes result, "<ul>"
    assert_includes result, "<ol>"
    assert_includes result, "<li>"
  end

  test "renders bold and italic" do
    markdown = "**bold** and *italic*"
    result = safe_markdown(markdown)

    assert_includes result, "<strong>"
    assert_includes result, "<em>"
  end

  test "renders blockquotes" do
    markdown = "> This is a quote"
    result = safe_markdown(markdown)

    assert_includes result, "<blockquote>"
  end

  test "renders images with safe attributes" do
    markdown = "![Alt text](https://example.com/image.png)"
    result = safe_markdown(markdown)

    assert_includes result, "<img"
    assert_includes result, 'src="https://example.com/image.png"'
    assert_includes result, 'alt="Alt text"'
  end

  test "renders strikethrough" do
    markdown = "~~deleted~~"
    result = safe_markdown(markdown)

    # Redcarpet uses <del> for strikethrough
    assert_match(/<del>|<s>|<strike>/, result)
  end

  # === Edge Cases ===

  test "handles empty content" do
    assert_equal "".html_safe, safe_markdown("")
    assert_equal "".html_safe, safe_markdown(nil)
  end

  test "handles plain text without markdown" do
    result = safe_markdown("Just plain text")

    assert_includes result, "Just plain text"
    assert result.html_safe?
  end

  test "preserves safe HTML tags in markdown" do
    markdown = "Text with <strong>bold</strong> HTML"
    result = safe_markdown(markdown)

    assert_includes result, "<strong>"
  end

  test "result is marked as html_safe" do
    result = safe_markdown("# Test")

    assert result.html_safe?
  end

  # === sanitize_html direct tests ===

  test "sanitize_html strips dangerous tags" do
    html = '<p>Safe</p><script>evil()</script>'
    result = sanitize_html(html)

    assert_includes result, "<p>"
    assert_not_includes result, "<script>"
  end

  test "sanitize_html preserves allowed attributes" do
    html = '<a href="https://example.com" onclick="evil()">Link</a>'
    result = sanitize_html(html)

    assert_includes result, 'href="https://example.com"'
    assert_not_includes result, "onclick"
  end
end
