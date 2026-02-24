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
      "/ok" => 200,
      "/missing" => 404,
      "/boom" => 500
    })

    results = DeadRouteScanner.scan(session: session, routes: ["/ok", "/missing", "/boom"])

    assert_equal [false, true, true], results.map { |r| r[:failed] }
    assert_equal [true, false, false], results.map { |r| r[:ok] }
  end

  test "scan captures exceptions as failed" do
    session = build_fake_session({ "/ok" => 200 }, raise_for: "/explode")

    results = DeadRouteScanner.scan(session: session, routes: ["/ok", "/explode"])
    exception_result = results.find { |r| r[:path] == "/explode" }

    assert exception_result[:failed]
    assert_equal "boom", exception_result[:exception]
    assert_nil exception_result[:status]
  end

  private

  def fake_route(verb, path, internal)
    FakeRoute.new(verb, FakePath.new(path), internal)
  end

  def build_fake_session(status_map, raise_for: nil)
    response = Struct.new(:status).new(200)

    Object.new.tap do |session|
      session.define_singleton_method(:response) { response }
      session.define_singleton_method(:get) do |path|
        raise StandardError, "boom" if path == raise_for

        response.status = status_map.fetch(path)
      end
    end
  end
end
