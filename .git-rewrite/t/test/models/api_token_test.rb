require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "generates token on create" do
    user = users(:one)
    api_token = user.api_tokens.create!(name: "New Token")

    assert api_token.token.present?
    assert_equal 64, api_token.token.length # 32 bytes hex = 64 chars
  end

  test "token must be unique" do
    existing_token = api_tokens(:one)
    user = users(:two)

    new_token = user.api_tokens.new(name: "Duplicate", token: existing_token.token)
    assert_not new_token.valid?
    assert_includes new_token.errors[:token], "has already been taken"
  end

  test "name is required" do
    user = users(:one)
    api_token = user.api_tokens.new(name: nil)

    assert_not api_token.valid?
    assert_includes api_token.errors[:name], "can't be blank"
  end

  test "authenticate returns user for valid token" do
    api_token = api_tokens(:one)
    user = ApiToken.authenticate(api_token.token)

    assert_equal api_token.user, user
  end

  test "authenticate returns nil for invalid token" do
    user = ApiToken.authenticate("invalid_token")
    assert_nil user
  end

  test "authenticate returns nil for blank token" do
    assert_nil ApiToken.authenticate(nil)
    assert_nil ApiToken.authenticate("")
  end

  test "authenticate updates last_used_at" do
    api_token = api_tokens(:one)
    assert_nil api_token.last_used_at

    ApiToken.authenticate(api_token.token)
    api_token.reload

    assert api_token.last_used_at.present?
  end

  test "belongs to user" do
    api_token = api_tokens(:one)
    assert_equal users(:one), api_token.user
  end
end
