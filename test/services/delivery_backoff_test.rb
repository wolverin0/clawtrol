# frozen_string_literal: true

require "test_helper"

class DeliveryBackoffTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
    @board = boards(:default)
    @task = @board.tasks.create!(
      user: @user,
      name: "Delivery Backoff Task",
      description: "Test delivery",
      status: :in_review,
      origin_chat_id: "12345"
    )
    ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"] = "test_token"
  end

  teardown do
    ENV.delete("CLAWTROL_TELEGRAM_BOT_TOKEN")
  end

  test "missing message_id triggers retries" do
    responses = [
      build_response({ "ok" => true, "result" => {} }),
      build_response({ "ok" => true }),
      build_response({ "ok" => true, "result" => { "message_id" => 123 } })
    ]
    call_count = 0
    sleeps = []

    Net::HTTP.stub(:post_form, ->(_uri, _params) {
      response = responses[call_count]
      call_count += 1
      response
    }) do
      Kernel.stub(:sleep, ->(duration) { sleeps << duration }) do
        ExternalNotificationService.new(@task).send(:send_telegram)
      end
    end

    assert_equal 3, call_count
    assert_equal [1, 5], sleeps
  end

  test "logs after three failures and continues" do
    response = build_response({ "ok" => true })
    call_count = 0
    sleeps = []
    logged = []

    Net::HTTP.stub(:post_form, ->(_uri, _params) {
      call_count += 1
      response
    }) do
      Kernel.stub(:sleep, ->(duration) { sleeps << duration }) do
        Rails.logger.stub(:warn, ->(message) { logged << message }) do
          assert_nothing_raised { ExternalNotificationService.new(@task).send(:send_telegram) }
        end
      end
    end

    assert_equal 4, call_count
    assert_equal [1, 5, 30], sleeps
    assert_includes logged, "[DeliveryBackoff] failed after 3 attempts"
  end

  private

  def build_response(payload)
    Struct.new(:body).new(payload.to_json)
  end
end
