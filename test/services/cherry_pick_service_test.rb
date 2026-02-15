# frozen_string_literal: true

require "test_helper"

class CherryPickServiceTest < ActiveSupport::TestCase
  test "pickable_commits returns result struct" do
    result = CherryPickService.pickable_commits(limit: 10)
    # Even if the remote is unreachable, it should return a Result
    assert result.respond_to?(:success)
    assert result.respond_to?(:message)
    assert result.respond_to?(:data)
  end

  test "pickable_commits returns array of commit hashes on success" do
    result = CherryPickService.pickable_commits(limit: 5)
    if result.success
      assert_kind_of Array, result.data
      result.data.each do |commit|
        assert commit.key?(:full_hash)
        assert commit.key?(:short_hash)
        assert commit.key?(:message)
        assert commit.key?(:date)
        assert commit.key?(:author)
        assert commit.key?(:factory)
        assert_match(/\A[a-f0-9]{40}\z/, commit[:full_hash])
        assert_match(/\A[a-f0-9]{7,}\z/, commit[:short_hash])
      end
    end
  end

  test "preview_commit rejects invalid hashes" do
    result = CherryPickService.preview_commit("not-a-hash!!")
    assert_equal false, result.success
    assert_equal "Invalid commit hash", result.message
  end

  test "preview_commit rejects empty string" do
    result = CherryPickService.preview_commit("")
    assert_equal false, result.success
  end

  test "preview_commit rejects nil" do
    result = CherryPickService.preview_commit(nil)
    assert_equal false, result.success
  end

  test "preview_commit returns diff for valid playground commit" do
    # Get the latest commit from playground
    latest = `git -C #{CherryPickService::PLAYGROUND_PATH} log --format=%H -1`.strip
    skip "No commits in playground" if latest.empty?

    result = CherryPickService.preview_commit(latest)
    assert result.success
    assert result.data[:hash].present?
    assert result.data[:diff].present?
    assert_kind_of Array, result.data[:files]
  end

  test "cherry_pick! rejects empty array" do
    result = CherryPickService.cherry_pick!([])
    assert_equal false, result.success
    assert_match(/No valid commit/, result.message)
  end

  test "cherry_pick! rejects invalid hashes" do
    result = CherryPickService.cherry_pick!(["xyz!", "abc$"])
    assert_equal false, result.success
  end

  test "cherry_pick! rejects non-hex strings" do
    result = CherryPickService.cherry_pick!(["hello-world"])
    assert_equal false, result.success
  end

  test "Result struct has expected attributes" do
    result = CherryPickService::Result.new(success: true, message: "ok", data: { foo: 1 })
    assert_equal true, result.success
    assert_equal "ok", result.message
    assert_equal({ foo: 1 }, result.data)
  end

  test "PLAYGROUND_PATH points to playground repo" do
    assert_match(/clawtrolplayground/, CherryPickService::PLAYGROUND_PATH)
  end

  test "PRODUCTION_PATH points to clawdeck" do
    assert_match(/clawdeck/, CherryPickService::PRODUCTION_PATH)
  end
end
