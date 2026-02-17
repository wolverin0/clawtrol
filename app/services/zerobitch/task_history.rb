# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"

module Zerobitch
  class TaskHistory
    MAX_ENTRIES = 100

    class << self
      def log(agent_id, prompt:, result:, duration_ms:, success:)
        entries = all(agent_id)
        entries << {
          id: "t_#{SecureRandom.hex(6)}",
          prompt: prompt.to_s,
          result: result.to_s,
          duration_ms: duration_ms.to_i,
          success: !!success,
          timestamp: Time.current.utc.iso8601
        }

        entries = entries.last(MAX_ENTRIES)
        write(agent_id, entries)
        entries.last
      end

      def all(agent_id)
        path = path_for(agent_id)
        return [] unless File.exist?(path)

        JSON.parse(File.read(path), symbolize_names: true)
      rescue JSON::ParserError
        []
      end

      def clear(agent_id)
        write(agent_id, [])
        true
      rescue StandardError
        false
      end

      private

      def path_for(agent_id)
        safe_id = agent_id.to_s.strip.downcase.gsub(/[^a-z0-9\-]/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
        safe_id = "agent" if safe_id.blank?

        Rails.root.join("storage", "zerobitch", "tasks", "#{safe_id}.json")
      end

      def write(agent_id, entries)
        path = path_for(agent_id)
        FileUtils.mkdir_p(path.dirname)
        File.write(path, JSON.pretty_generate(entries))
      end
    end
  end
end
