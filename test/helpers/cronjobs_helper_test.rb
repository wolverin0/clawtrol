# frozen_string_literal: true

require "test_helper"

class CronjobsHelperTest < ActionView::TestCase
  test "humanizes daily cron" do
    assert_equal "Daily at 1:00 AM", humanize_cron_expr("0 1 * * *")
  end

  test "humanizes weekly cron" do
    assert_equal "Sundays at 2:00 AM", humanize_cron_expr("0 2 * * 0")
  end

  test "humanizes every kind" do
    assert_equal "Every 30m", humanize_openclaw_schedule({ "kind" => "every", "everyMs" => 1_800_000 })
  end
end
