require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get health_url
    assert_response :success
    assert_equal "ok", JSON.parse(response.body)["status"]
  end
end
