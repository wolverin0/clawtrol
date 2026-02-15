# frozen_string_literal: true

require "test_helper"

class AuditReportTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    report = AuditReport.new(user: users(:one), report_type: "weekly", overall_score: 7.5)
    assert report.valid?
  end

  test "validates report_type inclusion" do
    report = AuditReport.new(user: users(:one), report_type: "monthly", overall_score: 7.5)
    assert_not report.valid?
    assert report.errors[:report_type].any?
  end

  test "validates overall_score range" do
    report = AuditReport.new(user: users(:one), report_type: "daily", overall_score: 11)
    assert_not report.valid?
    assert report.errors[:overall_score].any?
  end

  test "daily scope returns only daily reports" do
    daily = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 6.0)
    weekly = AuditReport.create!(user: users(:one), report_type: "weekly", overall_score: 8.0)

    assert_includes AuditReport.daily, daily
    assert_not_includes AuditReport.daily, weekly
  end

  test "recent scope orders by created_at desc" do
    older = AuditReport.create!(user: users(:one), report_type: "daily", overall_score: 5.0)
    newer = AuditReport.create!(user: users(:one), report_type: "weekly", overall_score: 9.0)

    older.update_columns(created_at: 2.days.ago)
    newer.update_columns(created_at: 1.day.ago)

    assert_equal [newer.id, older.id], AuditReport.recent.where(id: [older.id, newer.id]).pluck(:id)
  end
end
