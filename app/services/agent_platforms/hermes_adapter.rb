# frozen_string_literal: true

module AgentPlatforms
  # Hermes backend adapter. Implements the safe subset for MVP:
  #   - health/status
  #   - config + current model (read-only)
  #   - sessions list (read-only, if CLI supports --json)
  #   - cron list (read-only, if CLI supports --json)
  #
  # Anything that is not yet known to be implemented in the Hermes CLI
  # returns Result.unsupported(...) so callers stay correct without
  # waiting for parity.
  class HermesAdapter < BaseAdapter
    def key = "hermes"
    def label = "Hermes"

    # Available means: user opted into Hermes AND we can plausibly call it.
    # We treat presence of HERMES_HOME / hermes binary as a runtime concern
    # surfaced through health(), not by raising here.
    def available?
      true
    end

    def health
      result = cli.run("--version")
      case result[:status]
      when :ok
        Result.ok({ "status" => "ok", "version" => result[:stdout].strip }, platform: key)
      when :offline
        Result.offline(result[:stderr].to_s.strip.presence || "hermes offline", platform: key)
      else
        Result.error(result[:stderr].to_s.strip.presence || "hermes returned non-zero", platform: key)
      end
    end

    def config_get
      Result.unsupported("Hermes config may contain credentials; use Hermes CLI directly on the host for config inspection", platform: key)
    end

    def current_model
      status = cli.run("status", "--all")
      return coerce_text_result(status, label: "hermes status") unless status[:status] == :ok

      Result.ok(parse_model_from_status(status[:stdout]), platform: key)
    end

    def models_list
      Result.unsupported("Hermes CLI has no non-interactive models-list command; use `hermes model` interactively", platform: key)
    end

    def sessions_list
      coerce_text_result(cli.run("sessions", "list"), label: "hermes sessions")
    end

    def cron_list(all: true)
      args = ["cron", "list"]
      args << "--all" if all
      coerce_text_result(cli.run(*args), label: "hermes cron")
    end

    # Write operations + live session control are intentionally deferred
    # until we've verified Hermes CLI supports them stably with JSON output.
    # They inherit Result.unsupported(...) from BaseAdapter.

    def file_roots
      { "hermes" => Pathname.new(File.expand_path(ENV["HERMES_VIEWER_DIR"].presence || "~/.hermes/artifacts")) }
    end

    private

    def cli
      @cli ||= HermesCliRunner.new(user)
    end

    # Convert run_json output into a Result. run_json returns either parsed
    # JSON (Hash/Array) or a marker hash with "status" => "offline|error|unsupported".
    def coerce_result(parsed)
      if parsed.is_a?(Hash) && %w[offline unsupported error].include?(parsed["status"])
        case parsed["status"]
        when "offline"     then Result.offline(parsed["error"], platform: key)
        when "unsupported" then Result.unsupported(parsed["error"], platform: key)
        else                    Result.error(parsed["error"], platform: key)
        end
      else
        Result.ok(parsed, platform: key)
      end
    end

    def coerce_text_result(result, label: "hermes")
      case result[:status]
      when :ok
        Result.ok({ "raw" => result[:stdout].to_s }, platform: key)
      when :offline
        Result.offline(result[:stderr].to_s.strip.presence || "#{label} offline", platform: key)
      else
        Result.error(result[:stderr].to_s.strip.presence || "#{label} returned non-zero", platform: key)
      end
    end

    def parse_model_from_status(text)
      model = text.to_s[/^\s*Model:\s*(.+)$/i, 1]&.strip
      provider = text.to_s[/^\s*Provider:\s*(.+)$/i, 1]&.strip
      { "provider" => provider, "model" => model }
    end
  end
end
