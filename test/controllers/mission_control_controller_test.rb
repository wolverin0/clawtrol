require "test_helper"

class MissionControlControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get mission_control_url
    assert_response :success
    assert_select "h1", "Mission Control Health Dashboard"
    assert_select ".card", minimum: 3
  end
end