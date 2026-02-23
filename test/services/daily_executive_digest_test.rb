require "test_helper"

class DailyExecutiveDigestTest < ActiveSupport::TestCase
  test "generates digest payload" do
    # Simply test the keys are present and types are generally correct
    digest = DailyExecutiveDigest.new(Date.new(2026, 2, 23))
    result = digest.generate
    
    assert_equal Date.new(2026, 2, 23), result[:date]
    assert_kind_of Integer, result[:done]
    assert_kind_of Integer, result[:failed]
    assert_kind_of Integer, result[:blocked]
    assert_kind_of Array, result[:next_three]
  end
end
