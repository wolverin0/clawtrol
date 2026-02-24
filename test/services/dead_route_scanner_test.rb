# frozen_string_literal: true

require "test_helper"

class DeadRouteScannerTest < ActiveSupport::TestCase
  FakePath = Struct.new(:spec)
  FakeRoute = Struct.new(:verb, :path, :internal)

  test "route_paths keeps only scannable public GET routes" do
    routes = [
      fake_route("GET", "/boards(.:format)", false),
      fake_route("POST", "/boards(.:format)", false),
      fake_route("GET|POST", "/mixed(.:format)", false),
      fake_route("GET", "/boards/:id(.:format)", false),
      fake_route("GET", "/files/*path", false),
      fake_route("GET", "/rails/info(.:format)", false),
      fake_route("GET", "/assets/app.js", false),
      fake_route("GET", "/cable", false),
      fake_route("GET", "/a", false),
      fake_route("GET", "/internal(.:format)", true),
      fake_route("GET", "/boards(.:format)", false)
    ]

    assert_equal ["/boards", "/mixed"], DeadRouteScanner.route_paths(routes)
  end

  test "scan marks 404 and 500 responses as failed" do
    session = build_fake_session({
      "/ok" => { status: 200, body: "ok" },
      "/missing" => { status: 404, body: "not found" },
      "/boom" => { status: 500, body: "error" }
    })

    results = DeadRouteScanner.scan(session: session, routes: ["/ok", "/missing", "/boom"])

    assert_equal [false, true, true], results.map { |r| r[:failed] }
    assert_equal [true, false, false], results.map { |r| r[:ok] }
  end

  test "scan marks empty successful responses as failed" do
    session = build_fake_session({
      "/full" => { status: 200, body: "<h1>Dashboard</h1>" },
      "/empty" => { status: 200, body: "   " }
    })

    results = DeadRouteScanner.scan(session: session, routes: ["/full", "/empty"])

    assert_equal false, results.find { |r| r[:path] == "/full" }[:empty]

    empty_result = results.find { |r| r[:path] == "/empty" }
    assert_equal true, empty_result[:empty]
    assert_equal true, empty_result[:failed]
    assert_equal false, empty_result[:ok]
  end

  test "scan captures exceptions as failed without exposing raw error details" do
    session = build_fake_session({ "/ok" => { status: 200, body: "ok" } }, raise_for: "/explode")

    results = DeadRouteScanner.scan(session: session, routes: ["/ok", "/explode"])
    exception_result = results.find { |r| r[:path] == "/explode" }

    assert exception_result[:failed]
    assert_equal "StandardError: request failed", exception_result[:exception]
    refute_includes exception_result[:exception], "boom"
    assert_nil exception_result[:status]
  end

  private

  def fake_route(verb, path, internal)
    FakeRoute.new(verb, FakePath.new(path), internal)
  end

  def build_fake_session(status_map, raise_for: nil)
    response = Struct.new(:status, :body).new(200, "")

    Object.new.tap do |session|
      session.define_singleton_method(:response) { response }
      session.define_singleton_method(:get) do |path|
        raise StandardError, "boom" if path == raise_for

        payload = status_map.fetch(path)
        response.status = payload.fetch(:status)
        response.body = payload.fetch(:body)
      end
    end
  end
end
