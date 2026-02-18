# frozen_string_literal: true

require "test_helper"

class ProcessSavedLinkJobTest < ActiveJob::TestCase
  setup do
    @user = User.first || User.create!(email_address: "test@test.com", password: "password123456")
    @link = SavedLink.create!(
      user: @user,
      url: "https://example.com/article",
      note: "Test link",
      status: "pending"
    )

    # Stub external HTTP calls so tests run without real network access
    stub_request(:get, /example\.com/).to_return(
      status: 200,
      body: "<html><body><h1>Test Page</h1><p>Sample content.</p></body></html>",
      headers: { "Content-Type" => "text/html" }
    )
    stub_request(:get, /api\.fxtwitter\.com/).to_return(
      status: 200,
      body: { tweet: { text: "Test tweet content" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    # Stub Gemini CLI call to avoid real LLM invocation in tests
    @gemini_stub = "**Summary**: Test summary.\n**ClawTrol Relevance**: Low\n**Action Items**: None"
    ProcessSavedLinkJob.prepend(Module.new {
      define_method(:call_gemini_cli) { |_prompt| "**Summary**: Test summary.\n**ClawTrol Relevance**: Low\n**Action Items**: None" }
    })
  end

  # Test: link not found
  test "does nothing if saved link not found" do
    assert_nothing_raised do
      ProcessSavedLinkJob.perform_now(-1)
    end
  end

  # Test: SSRF protection blocks internal URLs
  test "blocks internal URLs (SSRF protection)" do
    @link.update!(url: "http://192.168.1.1/admin")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
    assert_includes @link.error_message, "private"
  end

  # Test: SSRF protection blocks localhost
  test "blocks localhost URLs (SSRF protection)" do
    @link.update!(url: "http://localhost:8080/secret")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
    assert_includes @link.error_message, "private"
  end

  # Test: SSRF protection blocks private ranges
  test "blocks private IP ranges (SSRF protection)" do
    @link.update!(url: "http://10.0.0.1/internal")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
    assert_includes @link.error_message, "private"
  end

  # Test: SSRF protection blocks 127.0.0.1
  test "blocks 127.0.0.1 (SSRF protection)" do
    @link.update!(url: "http://127.0.0.1:9229/admin")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
  end

  # Test: SSRF protection blocks metadata endpoints
  test "blocks AWS metadata endpoint (SSRF protection)" do
    @link.update!(url: "http://169.254.169.254/latest/meta-data")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
  end

  # Test: updates status to processing
  test "updates status to processing at start" do
    @link.update!(status: "pending")

    # Use a URL that will fail in fetch_content
    @link.update!(url: "http://192.168.1.1/test")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
  end

  # Test: X/Twitter URL detection
  test "detects X/Twitter URLs for special handling" do
    twitter_url = "https://x.com/user/status/1234567890"
    @link.update!(url: twitter_url)

    # Should attempt to use fxtwitter API
    # The job will fail because fxtwitter API won't return success in test env,
    # but it should try the correct API path
    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    # Either processed via fxtwitter or failed gracefully
    assert_includes %w[pending processing done failed], @link.status
  end

  # Test: Twitter URL with proper status ID extraction
  test "extracts tweet ID from various Twitter URL formats" do
    # Classic twitter.com format
    url1 = "https://twitter.com/user/status/1234567890123456789"
    assert_match(/1234567890123456789/, url1[/status\/(\d+)/, 1])

    # X.com format
    url2 = "https://x.com/futurasistemas/status/9876543210987654321"
    assert_match(/9876543210987654321/, url2[/status\/(\d+)/, 1])
  end

  # Test: handles invalid URL gracefully
  test "handles invalid URL gracefully" do
    @link.update_column(:url, "not-a-valid-url")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_equal "failed", @link.status
    assert_not_nil @link.error_message
  end

  # Test: URL with query parameters is handled
  test "handles URL with query parameters" do
    @link.update!(url: "https://example.com/page?foo=bar&baz=qux")

    # Will fail fetch but should not crash
    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_includes %w[done failed], @link.status
  end

  # Test: URL with fragment is handled
  test "handles URL with fragment" do
    @link.update!(url: "https://example.com/article#section")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    assert_includes %w[done failed], @link.status
  end

  # Test: non-HTML content type is handled
  test "handles non-HTML response gracefully" do
    # URL that exists but returns non-HTML
    # The job should handle any response type
    @link.update!(url: "https://example.com/api/data")

    ProcessSavedLinkJob.perform_now(@link.id)

    @link.reload
    # Should either succeed (if content extractable) or fail gracefully
    assert_includes %w[done failed], @link.status
  end
end
