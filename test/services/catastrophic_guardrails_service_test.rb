# frozen_string_literal: true

require "test_helper"

class CatastrophicGuardrailsServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.delete("clawdeck:guardrails:last_counts")
  end

  test "alerts when users table is empty" do
    notifications_before = Notification.count

    service = CatastrophicGuardrailsService.new
    service.define_singleton_method(:current_counts) { { users: 0, boards: 1, tasks: 1 } }

    with_env(
      "CLAWTROL_TELEGRAM_BOT_TOKEN" => nil,
      "CLAWTROL_TELEGRAM_ALERT_CHAT_ID" => nil
    ) do
      events = service.check!
      assert events.any? { |e| e[:kind] == "users_empty" }
    end

    assert_operator Notification.count, :>=, notifications_before
  end

  test "alerts on abrupt tasks drop" do
    service = CatastrophicGuardrailsService.new
    events = service.send(
      :drop_events_for,
      :tasks,
      { tasks: 10, users: 10, boards: 10 },
      { tasks: 2, users: 10, boards: 10 },
      50
    )
    assert events.any? { |e| e[:kind] == "tasks_dropped" }, "events=#{events.inspect}"
  end

  test "fail_fast raises" do
    service = CatastrophicGuardrailsService.new(mode: "fail_fast")
    service.define_singleton_method(:current_counts) { { users: 0, boards: 1, tasks: 1 } }
    with_env(
      "CLAWTROL_TELEGRAM_BOT_TOKEN" => nil,
      "CLAWTROL_TELEGRAM_ALERT_CHAT_ID" => nil
    ) do
      assert_raises(CatastrophicGuardrailsService::CatastrophicDataLossError) do
        service.check!
      end
    end
  end

  private

  def with_env(vars)
    previous = {}
    vars.each do |key, value|
      previous[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    vars.each_key do |key|
      if previous[key].nil?
        ENV.delete(key)
      else
        ENV[key] = previous[key]
      end
    end
  end
end
