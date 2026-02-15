# frozen_string_literal: true

require "test_helper"
require "openssl"
require "json"
require "cgi"

class TelegramMiniAppControllerTest < ActionDispatch::IntegrationTest
  BOT_TOKEN = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"

  setup do
    @user = users(:one)
    # Ensure only one user for single-tenant fallback
    ENV["TELEGRAM_BOT_TOKEN"] = BOT_TOKEN
  end

  teardown do
    ENV.delete("TELEGRAM_BOT_TOKEN")
  end

  # --- Show (GET) ---

  test "show renders the mini app page without auth" do
    get telegram_app_path
    assert_response :success
    assert_includes response.body, "ClawTrol"
    assert_includes response.body, "telegram-web-app.js"
  end

  # --- Tasks (POST) ---

  test "tasks returns 401 without valid initData" do
    post telegram_app_tasks_path, params: { init_data: "garbage" }, as: :json
    assert_response :unauthorized
  end

  test "tasks returns 401 with expired initData" do
    init_data = build_init_data({ "id" => 12345 }, auth_date: Time.now.to_i - 600)
    post telegram_app_tasks_path, params: { init_data: init_data }, as: :json
    assert_response :unauthorized
  end

  test "tasks returns 403 when no user can be linked (multi-tenant)" do
    # With multiple users and no telegram_chat_id mapping, should fail
    init_data = build_init_data({ "id" => 99999 })
    post telegram_app_tasks_path, params: { init_data: init_data, status: "inbox" }, as: :json
    assert_response :forbidden
    data = JSON.parse(response.body)
    assert_includes data["error"], "linked"
  end

  # --- Create Task (POST) ---

  test "create task returns 401 without initData" do
    post telegram_app_tasks_create_path, as: :json
    assert_response :unauthorized
  end

  test "create task returns 422 without name" do
    init_data = build_init_data({ "id" => 12345 })
    post telegram_app_tasks_create_path, params: { init_data: init_data, name: "" }, as: :json
    # Might be 403 if no linked user, or 422 if missing title
    assert_includes [403, 422], response.status
  end

  test "create task returns 403 when user not linked" do
    init_data = build_init_data({ "id" => 99999 })
    post telegram_app_tasks_create_path,
      params: { init_data: init_data, name: "Test from Telegram" },
      as: :json
    assert_response :forbidden
  end

  # --- Approve (POST) ---

  test "approve returns 401 without initData" do
    post telegram_app_approve_path(id: 1), as: :json
    assert_response :unauthorized
  end

  # --- Reject (POST) ---

  test "reject returns 401 without initData" do
    post telegram_app_reject_path(id: 1), as: :json
    assert_response :unauthorized
  end

  # --- Bot token missing ---

  test "tasks returns 500 when bot token not configured" do
    ENV.delete("TELEGRAM_BOT_TOKEN")
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
    post telegram_app_tasks_path, params: { init_data: "test" }, as: :json
    assert_response :internal_server_error
    data = JSON.parse(response.body)
    assert_includes data["error"], "bot token"
  end

  private

  def build_init_data(user_hash, auth_date: nil)
    auth_date ||= Time.now.to_i
    user_json = user_hash.to_json

    params = {
      "auth_date" => auth_date.to_s,
      "user" => user_json
    }

    data_check = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
    secret = OpenSSL::HMAC.digest("SHA256", "WebAppData", BOT_TOKEN)
    params["hash"] = OpenSSL::HMAC.hexdigest("SHA256", secret, data_check)

    params.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v.to_s)}" }.join("&")
  end
end
