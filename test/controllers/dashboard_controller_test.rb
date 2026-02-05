require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should redirect to login when not authenticated" do
    get dashboard_path
    assert_response :redirect
  end

  test "should get show when authenticated" do
    sign_in_as(@user)
    get dashboard_path
    assert_response :success
    assert_select "div.text-2xl.font-bold"  # Check for status cards
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end
