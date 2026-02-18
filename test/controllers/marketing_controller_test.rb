# frozen_string_literal: true

require "test_helper"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
  end

  # --- Unauthenticated routes ---

  test "index is accessible without auth" do
    get "/marketing"
    assert_response :success
  end

  test "playground is accessible without auth" do
    get "/marketing/playground"
    assert_response :success
  end

  # --- sanitize_filename_component ---

  test "sanitize_filename_component strips path traversal chars" do
    controller = MarketingController.new
    assert_equal "futura", controller.send(:sanitize_filename_component, "../../futura")
    assert_equal "futuraetc", controller.send(:sanitize_filename_component, "futura/../../etc")
    assert_equal "futura", controller.send(:sanitize_filename_component, "../futura")
    # Dots, slashes, and special chars are all stripped — only alphanum, hyphen, underscore remain
    assert_equal "unknown", controller.send(:sanitize_filename_component, "../../")
  end

  test "sanitize_filename_component strips shell metacharacters" do
    controller = MarketingController.new
    assert_equal "futuracrm", controller.send(:sanitize_filename_component, "futura;crm")
    assert_equal "futuracrm", controller.send(:sanitize_filename_component, "futura|crm")
    assert_equal "futuracrm", controller.send(:sanitize_filename_component, "futura&crm")
  end

  test "sanitize_filename_component allows clean names" do
    controller = MarketingController.new
    assert_equal "futuracrm", controller.send(:sanitize_filename_component, "futuracrm")
    assert_equal "futura-fitness", controller.send(:sanitize_filename_component, "futura-fitness")
    assert_equal "my_product_v2", controller.send(:sanitize_filename_component, "my_product_v2")
  end

  test "sanitize_filename_component returns unknown for blank" do
    controller = MarketingController.new
    assert_equal "unknown", controller.send(:sanitize_filename_component, "")
    assert_equal "unknown", controller.send(:sanitize_filename_component, "../../")
    assert_equal "unknown", controller.send(:sanitize_filename_component, "...")
  end

  # --- sanitize_path ---

  test "sanitize_path rejects directory traversal" do
    controller = MarketingController.new
    assert_equal "", controller.send(:sanitize_path, "../../etc/passwd")
    assert_equal "", controller.send(:sanitize_path, "foo/../bar")
  end

  test "sanitize_path rejects null bytes" do
    controller = MarketingController.new
    assert_equal "", controller.send(:sanitize_path, "foo\x00bar")
  end

  test "sanitize_path rejects dotfiles" do
    controller = MarketingController.new
    assert_equal "", controller.send(:sanitize_path, ".env")
    assert_equal "", controller.send(:sanitize_path, ".git/config")
  end

  test "sanitize_path allows clean paths" do
    controller = MarketingController.new
    assert_equal "docs/readme.md", controller.send(:sanitize_path, "docs/readme.md")
    assert_equal "generated/image.png", controller.send(:sanitize_path, "generated/image.png")
  end

  # --- generate_image requires auth ---

  test "generate_image requires authentication" do
    post "/marketing/generate_image", params: { prompt: "test" }
    # Should redirect to login or return 401
    assert_response :redirect
  end

  # --- generate_image validation ---

  test "generate_image rejects blank prompt" do
    sign_in_as(@user)
    post "/marketing/generate_image", params: { prompt: "" }
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "Prompt"
  end

  test "generate_image rejects unsupported model" do
    sign_in_as(@user)
    post "/marketing/generate_image", params: { prompt: "test", model: "dall-e-2" }
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "not supported"
  end
end
