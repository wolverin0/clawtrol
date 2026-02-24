# frozen_string_literal: true

class DeadRouteScanner
  EXCLUDED_PREFIXES = ["/rails/", "/assets/", "/cable"].freeze
  MIN_PATH_LENGTH = 3

  class << self
    def route_paths(routes = Rails.application.routes.routes)
      routes.filter_map do |route|
        path = normalized_path(route)
        next unless scannable_get_route?(route, path)

        path
      end.uniq
    end

    def scan(session: ActionDispatch::Integration::Session.new(Rails.application), routes: route_paths)
      routes.map do |path|
        begin
          session.get(path)
          status = session.response.status
          {
            path: path,
            status: status,
            ok: status < 400,
            failed: status >= 500 || status == 404,
            exception: nil
          }
        rescue StandardError => e
          {
            path: path,
            status: nil,
            ok: false,
            failed: true,
            exception: e.message
          }
        end
      end
    end

    private

    def normalized_path(route)
      route.path.spec.to_s.delete_suffix("(.:format)")
    end

    def scannable_get_route?(route, path)
      supports_get_verb?(route.verb) &&
        !route.internal &&
        path !~ /:/ &&
        path.length >= MIN_PATH_LENGTH &&
        EXCLUDED_PREFIXES.none? { |prefix| path.start_with?(prefix) }
    end

    def supports_get_verb?(verb)
      verb.to_s.split("|").include?("GET")
    end
  end
end
