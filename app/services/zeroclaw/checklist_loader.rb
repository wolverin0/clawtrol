# frozen_string_literal: true

require "yaml"

module Zeroclaw
  class ChecklistLoader
    BASE_DIR = Rails.root.join("config", "auditor-checklists")

    class << self
      def load(task_type)
        normalized = task_type.to_s.downcase
        path = BASE_DIR.join("#{normalized}.yml")
        path = BASE_DIR.join("default.yml") unless path.exist?

        YAML.safe_load(path.read, permitted_classes: [], aliases: false) || {}
      rescue StandardError => e
        Rails.logger.warn("[Zeroclaw::ChecklistLoader] failed for #{task_type}: #{e.class}: #{e.message}")
        {}
      end
    end
  end
end
