# frozen_string_literal: true

require "test_helper"
require "ostruct"

class DailyExecutiveDigestServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @user.update!(telegram_chat_id: "123456789")
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "fake_token"
    ENV["CLAWTROL_TELEGRAM_CHAT_ID"] = nil
    ENV["TELEGRAM_CHAT_ID"] = nil
  end

  def teardown
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
  end

  test "sends digest with tasks" do
    board = @user.boards.first || @user.boards.create!(name: "Test")
    @user.tasks.create!(name: "Done Task", status: "done", board: board)
    @user.tasks.create!(name: "Failed Task", error_message: "Failed", board: board)
    @user.tasks.create!(name: "Blocked Task", blocked: true, board: board)
    @user.tasks.create!(name: "Next Task", status: "up_next", board: board)

    mock_response = Minitest::Mock.new
    mock_response.expect(:code, "200")

    Net::HTTP.stub(:post_form, ->(uri, params) { mock_response.code; mock_response }) do
      DailyExecutiveDigestService.new.send(:send_digest, @user)
    end

    assert_mock mock_response
  end

  test "sends empty digest when no tasks" do
    @user.tasks.destroy_all

    mock_response = Minitest::Mock.new
    mock_response.expect(:code, "200")

    Net::HTTP.stub(:post_form, ->(uri, params) { mock_response.code; mock_response }) do
      DailyExecutiveDigestService.new.send(:send_digest, @user)
    end

    assert_mock mock_response
  end

  test "escapes html in task names for telegram html parse mode" do
    board = @user.boards.first || @user.boards.create!(name: "Test")
    @user.tasks.create!(name: "<b>boom</b> & \"quoted\"", status: "done", board: board)

    captured_text = nil

    Net::HTTP.stub(:post_form, ->(_uri, params) { captured_text = params[:text]; OpenStruct.new(code: "200") }) do
      DailyExecutiveDigestService.new.send(:send_digest, @user)
    end

    assert_includes captured_text, "• &lt;b&gt;boom&lt;/b&gt; &amp; &quot;quoted&quot;"
    refute_includes captured_text, "• <b>boom</b>"
  end

  test "skips users without telegram config" do
    @user.update!(telegram_chat_id: nil)

    assert_nothing_raised do
      DailyExecutiveDigestService.call
    end
  end
end
