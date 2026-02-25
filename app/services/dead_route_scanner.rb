# frozen_string_literal: true

class DeadRouteScanner
  EXCLUDED_PREFIXES = ["/rails/", "/assets/", "/cable"].freeze
  MIN_PATH_LENGTH = 3

  class << self
    def route_paths(routes = Rails.application.routes.routes)
      seen_paths = {}

      routes.each_with_object([]) do |route, paths|
        path = normalized_path(route)
        next unless scannable_get_route?(route, path)
        next if seen_paths[path]

        seen_paths[path] = true
        paths << path
      end
    end

    def scan(session: ActionDispatch::Integration::Session.new(Rails.application), routes: route_paths)
      routes.map do |path|
        begin
          session.get(path)
          status = session.response.status
          empty = empty_success_response?(status, session.response)
          turbo_frame_mismatch = turbo_frame_mismatch_response?(status, session.response)

          success_result(path: path, status: status, empty: empty, turbo_frame_mismatch: turbo_frame_mismatch)
        rescue StandardError => e
          failure_result(path: path, exception: safe_exception_message(e))
        end
      end
    end

    private

    def normalized_path(route)
      spec = route&.path&.spec
      return nil if spec.blank?

      spec.to_s.delete_suffix("(.:format)")
    end

    def scannable_get_route?(route, path)
      return false if path.blank?

      supports_get_verb?(route.verb) &&
        path.start_with?("/") &&
        !route.internal &&
        path !~ /[:*]/ &&
        (path == "/" || path.length >= MIN_PATH_LENGTH) &&
        EXCLUDED_PREFIXES.none? { |prefix| path.start_with?(prefix) }
    end

    def supports_get_verb?(verb)
      verb.to_s.match?(/\bGET\b/)
    end

    def empty_success_response?(status, response)
      status.between?(200, 299) && response.body.to_s.strip.empty?
    end

    def turbo_frame_mismatch_response?(status, response)
      return false unless status.between?(200, 299)

      body = response.body.to_s
      body.include?("did not contain the expected <turbo-frame")
    end

    def success_result(path:, status:, empty:, turbo_frame_mismatch: false)
      {
        path: path,
        status: status,
        ok: status < 400 && !empty && !turbo_frame_mismatch,
        failed: status >= 500 || status == 404 || empty || turbo_frame_mismatch,
        empty: empty,
        turbo_frame_mismatch: turbo_frame_mismatch,
        exception: nil
      }
    end

    def failure_result(path:, exception:)
      {
        path: path,
        status: nil,
        ok: false,
        failed: true,
        empty: false,
        turbo_frame_mismatch: false,
        exception: exception
      }
    end

    def safe_exception_message(error)
      "#{error.class.name}: request failed"
    end
  end
end
