require "test_helper"

class CommandControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "unauthenticated request redirects to login" do
    get command_path(format: :json)
    assert_response :redirect
  end

  test "returns CLI session JSON when authenticated" do
    sign_in_as(@user)

    sample = {
      path: "/tmp/sessions.json",
      count: 1,
      activeMinutes: 120,
      sessions: [
        {
          key: "agent:main:main",
          kind: "direct",
          updatedAt: 1_700_000_000_000,
          ageMs: 12_345,
          sessionId: "abc",
          totalTokens: 42,
          model: "gpt-5.3-codex",
          abortedLastRun: false
        }
      ]
    }.to_json

    fake_status = Struct.new(:success?, :exitstatus).new(true, 0)

    with_stubbed_capture3([sample, "", fake_status]) do
      get command_path(format: :json)
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "online", body["status"]
    assert_equal "cli", body["source"]
    assert_equal 1, body["count"]
    assert_equal 120, body["activeMinutes"]

    assert_kind_of Array, body["sessions"]
    assert_equal 1, body["sessions"].length
    assert_equal "agent:main:main", body["sessions"][0]["key"]
    assert_equal 42, body["sessions"][0]["totalTokens"]
  end

  test "returns 503 offline when openclaw is missing" do
    sign_in_as(@user)

    with_stubbed_capture3(->(*) { raise Errno::ENOENT }) do
      get command_path(format: :json)
    end

    assert_response :service_unavailable
    body = JSON.parse(response.body)
    assert_equal "offline", body["status"]
    assert_includes body["error"], "openclaw"
  end

  private

  def with_stubbed_capture3(impl)
    original = Open3.method(:capture3)

    Open3.define_singleton_method(:capture3) do |*args|
      impl.respond_to?(:call) ? impl.call(*args) : impl
    end

    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*args| original.call(*args) }
  end
end
