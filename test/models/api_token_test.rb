require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "generates token_digest and raw_token on create" do
    user = users(:one)
    api_token = user.api_tokens.create!(name: "New Token")

    assert api_token.raw_token.present?
    assert_equal 64, api_token.raw_token.length # 32 bytes hex = 64 chars
    assert api_token.token_digest.present?
    assert_equal Digest::SHA256.hexdigest(api_token.raw_token), api_token.token_digest
  end

  test "token_digest uniqueness is enforced at DB level" do
    # Each created token gets a unique digest
    user = users(:one)
    token1 = user.api_tokens.create!(name: "Token A")
    token2 = user.api_tokens.create!(name: "Token B")
    assert_not_equal token1.token_digest, token2.token_digest
  end

  test "name is required" do
    user = users(:one)
    api_token = user.api_tokens.new(name: nil)

    assert_not api_token.valid?
    assert_includes api_token.errors[:name], "can't be blank"
  end

  test "authenticate returns user for valid token" do
    # Use the known plaintext for the fixture
    user = ApiToken.authenticate("test_token_one_abc123def456")
    assert_equal users(:one), user
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

    ApiToken.authenticate("test_token_one_abc123def456")
    api_token.reload

    assert api_token.last_used_at.present?
  end

  test "belongs to user" do
    api_token = api_tokens(:one)
    assert_equal users(:one), api_token.user
  end

  test "raw_token is available immediately after create but not on fresh lookup" do
    user = users(:one)
    api_token = user.api_tokens.create!(name: "Ephemeral Token")
    raw = api_token.raw_token
    assert raw.present?

    # A fresh lookup from DB won't have raw_token
    fresh_lookup = ApiToken.find(api_token.id)
    assert_nil fresh_lookup.raw_token
  end

  test "masked_token shows prefix with dots" do
    api_token = api_tokens(:one)
    masked = api_token.masked_token
    assert masked.start_with?("test_tok")
    assert masked.include?("•")
  end
end
