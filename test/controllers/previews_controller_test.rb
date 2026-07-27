# frozen_string_literal: true

require "test_helper"

class PreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_project_dir = ENV["CLAWTROL_PROJECT_DIR"]
    ENV["CLAWTROL_PROJECT_DIR"] = Rails.root.join("test/fixtures/files").to_s
    @user = users(:default)
    @task = tasks(:malicious_artifact)
    sign_in_as(@user)
  end

  teardown do
    ENV["CLAWTROL_PROJECT_DIR"] = @original_project_dir
  end

  test "raw HTML is an inert text attachment" do
    get raw_output_path(@task)

    assert_response :success
    assert_includes response.media_type, "text/plain"
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "sandbox; default-src 'none'", response.headers["Content-Security-Policy"]
    assert_includes response.body, "<script>"
  end

  test "show escapes malicious HTML and contains no iframe" do
    get output_path(@task)

    assert_response :success
    assert_includes response.body, "&lt;script&gt;"
    refute_includes response.body, "<iframe"
    assert_includes response.body, "Interactive HTML previewing is temporarily disabled"
  end
end
