# frozen_string_literal: true

require "test_helper"
require "openssl"
require "json"
require "cgi"

class TelegramInitDataValidatorTest < ActiveSupport::TestCase
  BOT_TOKEN = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"

  test "rejects empty initData" do
    result = TelegramInitDataValidator.new("", bot_token: BOT_TOKEN).validate
    assert_not result.valid?
    assert_equal "Missing initData", result.error
  end

  test "rejects nil initData" do
    result = TelegramInitDataValidator.new(nil, bot_token: BOT_TOKEN).validate
    assert_not result.valid?
    assert_equal "Missing initData", result.error
  end

  test "rejects missing bot token" do
    result = TelegramInitDataValidator.new("hash=abc", bot_token: "").validate
    assert_not result.valid?
    assert_equal "Missing bot token", result.error
  end

  test "rejects initData without hash" do
    result = TelegramInitDataValidator.new("user=test&auth_date=123", bot_token: BOT_TOKEN).validate
    assert_not result.valid?
    assert_equal "Missing hash in initData", result.error
  end

  test "rejects invalid hash" do
    init_data = build_init_data({ "id" => 12345, "first_name" => "Snake" }, hash: "deadbeef")
    result = TelegramInitDataValidator.new(init_data, bot_token: BOT_TOKEN).validate
    assert_not result.valid?
    assert_equal "Invalid hash", result.error
  end

  test "accepts valid initData with correct HMAC" do
    init_data = build_init_data({ "id" => 12345, "first_name" => "Snake" })
    result = TelegramInitDataValidator.new(init_data, bot_token: BOT_TOKEN).validate
    assert result.valid?, "Expected valid but got: #{result.error}"
    assert_equal 12345, result.user["id"]
    assert_equal "Snake", result.user["first_name"]
  end

  test "rejects expired initData" do
    expired_time = Time.now.to_i - 600 # 10 minutes ago
    init_data = build_init_data({ "id" => 99 }, auth_date: expired_time)
    result = TelegramInitDataValidator.new(init_data, bot_token: BOT_TOKEN).validate
    assert_not result.valid?
    assert_equal "initData expired", result.error
  end

  test "handles initData with no user field" do
    params = { "auth_date" => Time.now.to_i.to_s, "query_id" => "test123" }
    data_check = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
    secret = OpenSSL::HMAC.digest("SHA256", "WebAppData", BOT_TOKEN)
    hash = OpenSSL::HMAC.hexdigest("SHA256", secret, data_check)
    init_data = params.merge("hash" => hash).map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join("&")

    result = TelegramInitDataValidator.new(init_data, bot_token: BOT_TOKEN).validate
    assert result.valid?
    assert_nil result.user
  end

  private

  def build_init_data(user_hash, auth_date: nil, hash: nil)
    auth_date ||= Time.now.to_i
    user_json = user_hash.to_json

    params = {
      "auth_date" => auth_date.to_s,
      "user" => user_json
    }

    if hash
      params["hash"] = hash
    else
      data_check = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
      secret = OpenSSL::HMAC.digest("SHA256", "WebAppData", BOT_TOKEN)
      params["hash"] = OpenSSL::HMAC.hexdigest("SHA256", secret, data_check)
    end

    params.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v.to_s)}" }.join("&")
  end
end
