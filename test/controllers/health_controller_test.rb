require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_revision = ENV["APP_REVISION"]
  end

  teardown do
    ENV["APP_REVISION"] = @original_revision
  end

  test "returns the immutable release revision without caching" do
    ENV["APP_REVISION"] = "a" * 40

    get health_url

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "ok", payload["status"]
    assert_equal "a" * 40, payload["revision"]
    assert_equal true, payload.dig("checks", "revision", "ok")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "production revision check rejects a mutable or missing revision" do
    ENV.delete("APP_REVISION")
    production = ActiveSupport::EnvironmentInquirer.new("production")

    result = Rails.stub(:env, production) do
      HealthController.new.send(:check_revision)
    end

    assert_equal false, result[:ok]
    assert_match(/tested 40-character Git SHA/, result[:error])
  end
end
