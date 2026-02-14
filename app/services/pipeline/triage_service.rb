# frozen_string_literal: true

module Pipeline
  class TriageService
    VOTE_WEIGHTS = {
      template_override: 10,
      board_default: 5,
      tag_match: 3,
      name_pattern: 2,
      description_keyword: 1
    }.freeze

    def initialize(task)
      @task = task
      @config = self.class.config
    end

    def call
      votes = collect_votes
      return nil if votes.empty?

      # Pick the pipeline type with highest total weight
      winner = votes.group_by { |v| v[:pipeline_type] }
                    .transform_values { |vs| vs.sum { |v| v[:weight] } }
                    .max_by { |_type, weight| weight }

      result = {
        pipeline_type: winner[0],
        confidence: winner[1],
        votes: votes,
        triaged_at: Time.current.iso8601
      }

      log_entry = { stage: "triage", result: result, at: Time.current.iso8601 }

      if observation_mode?
        append_pipeline_log(@task, log_entry)
      else
        @task.update_columns(
          pipeline_type: result[:pipeline_type],
          pipeline_stage: "triaged",
          pipeline_log: Array(@task.pipeline_log).push(log_entry)
        )
      end

      result
    end

    def self.config
      @config ||= load_config
    end

    def self.reload_config!
      @config = load_config
    end

    def self.load_config
      path = Rails.root.join("config", "pipelines.yml")
      YAML.load_file(path).deep_symbolize_keys
    rescue StandardError => e
      Rails.logger.error("[Pipeline::TriageService] Failed to load config: #{e.message}")
      {}
    end

    private

    def observation_mode?
      @config[:observation_mode] == true
    end

    def collect_votes
      votes = []

      # Priority 1: Template override (highest weight)
      if (template_type = template_override_type)
        votes << { source: :template_override, pipeline_type: template_type, weight: VOTE_WEIGHTS[:template_override] }
      end

      # Priority 2: Board default mapping
      if (board_type = board_default_type)
        votes << { source: :board_default, pipeline_type: board_type, weight: VOTE_WEIGHTS[:board_default] }
      end

      # Priority 3: Tag matching
      tag_matches = tag_match_types
      tag_matches.each do |type|
        votes << { source: :tag_match, pipeline_type: type, weight: VOTE_WEIGHTS[:tag_match] }
      end

      # Priority 4: Name pattern matching
      name_matches = name_pattern_types
      name_matches.each do |type|
        votes << { source: :name_pattern, pipeline_type: type, weight: VOTE_WEIGHTS[:name_pattern] }
      end

      # Priority 5: Description keyword matching (only for short descriptions)
      desc_matches = description_keyword_types
      desc_matches.each do |type|
        votes << { source: :description_keyword, pipeline_type: type, weight: VOTE_WEIGHTS[:description_keyword] }
      end

      # Fallback to default if no votes
      if votes.empty?
        default_type = @config[:default_pipeline]&.to_s || "quick-fix"
        votes << { source: :default, pipeline_type: default_type, weight: 0 }
      end

      votes
    end

    def template_override_type
      return nil unless @task.respond_to?(:task_template_slug) && @task.task_template_slug.present?

      slug = @task.task_template_slug
      pipelines.each do |type, cfg|
        slugs = cfg.dig(:match_rules, :template_slugs) || []
        return type.to_s if slugs.include?(slug)
      end

      # Check TaskTemplate pipeline_type override
      template = TaskTemplate.find_by(slug: slug)
      template&.pipeline_type
    end

    def board_default_type
      board_name = @task.board&.name
      return nil unless board_name

      board_defaults = @config[:board_defaults] || {}
      board_defaults[board_name.to_sym]&.to_s || board_defaults[board_name]&.to_s
    end

    def tag_match_types
      task_tags = Array(@task.tags).map(&:to_s).map(&:downcase)
      return [] if task_tags.empty?

      matches = []
      pipelines.each do |type, cfg|
        rule_tags = (cfg.dig(:match_rules, :tags_any) || []).map(&:to_s).map(&:downcase)
        matches << type.to_s if (task_tags & rule_tags).any?
      end
      matches
    end

    def name_pattern_types
      name = @task.name.to_s
      return [] if name.blank?

      matches = []
      pipelines.each do |type, cfg|
        patterns = cfg.dig(:match_rules, :name_patterns) || []
        if patterns.any? { |p| name.match?(Regexp.new(p)) }
          matches << type.to_s
        end
      end
      matches
    rescue RegexpError => e
      Rails.logger.warn("[Pipeline::TriageService] Regex error in name patterns: #{e.message}")
      []
    end

    def description_keyword_types
      desc = @task.description.to_s
      return [] if desc.blank? || desc.length > 1000

      name = @task.name.to_s
      text = "#{name} #{desc}".downcase

      matches = []
      pipelines.each do |type, cfg|
        tags = (cfg.dig(:match_rules, :tags_any) || []).map(&:to_s).map(&:downcase)
        matches << type.to_s if tags.any? { |tag| text.include?(tag) }
      end
      matches
    end

    def pipelines
      @config[:pipelines] || {}
    end

    def append_pipeline_log(task, entry)
      current = Array(task.pipeline_log)
      task.update_columns(pipeline_log: current.push(entry))
    end
  end
end
