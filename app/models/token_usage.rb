class TokenUsage < ApplicationRecord
  belongs_to :task
  belongs_to :agent_persona, optional: true

  # Cost per 1M tokens (USD)
  COSTS = {
    "opus" => { input: 15.0, output: 75.0 },
    "sonnet" => { input: 3.0, output: 15.0 },
    "codex" => { input: 2.0, output: 10.0 },
    "gemini" => { input: 0.0, output: 0.0 },  # free tier
    "glm" => { input: 0.5, output: 2.0 }
  }.freeze

  # Model badge colors (consistent with existing UI)
  MODEL_COLORS = {
    "opus" => "purple",
    "sonnet" => "orange",
    "codex" => "blue",
    "gemini" => "emerald",
    "glm" => "amber"
  }.freeze

  validates :model, presence: true
  validates :input_tokens, numericality: { greater_than_or_equal_to: 0 }
  validates :output_tokens, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_model, ->(model) { where(model: model) }
  scope :by_date_range, ->(start_date, end_date = Time.current) { where("token_usages.created_at" => start_date..end_date) }
  scope :by_board, ->(board_id) { joins(:task).where(tasks: { board_id: board_id }) }
  scope :for_user, ->(user) { joins(:task).where(tasks: { user_id: user.id }) }

  before_save :calculate_cost, if: -> { input_tokens_changed? || output_tokens_changed? || model_changed? }

  # Calculate cost based on model and token counts
  def calculate_cost
    rates = COSTS[normalize_model(model)] || COSTS["sonnet"]
    input_cost = (input_tokens.to_f / 1_000_000) * rates[:input]
    output_cost = (output_tokens.to_f / 1_000_000) * rates[:output]
    self.cost = input_cost + output_cost
  end

  # Total tokens for this record
  def total_tokens
    input_tokens.to_i + output_tokens.to_i
  end

  # Class methods for aggregations
  class << self
    # Total cost for a collection
    def total_cost
      sum(:cost)
    end

    # Total tokens for a collection
    def total_input
      sum(:input_tokens)
    end

    def total_output
      sum(:output_tokens)
    end

    def total_tokens_count
      sum(:input_tokens) + sum(:output_tokens)
    end

    # Cost breakdown grouped by model
    def cost_by_model
      group(:model).sum(:cost).sort_by { |_, v| -v }.to_h
    end

    # Token breakdown grouped by model
    def tokens_by_model
      group(:model).select(
        "model",
        "SUM(input_tokens) as total_input",
        "SUM(output_tokens) as total_output",
        "SUM(cost) as total_cost",
        "COUNT(*) as usage_count"
      )
    end

    # Usage over time (daily)
    def daily_usage(start_date = 30.days.ago)
      where("token_usages.created_at >= ?", start_date)
        .group("DATE(token_usages.created_at)")
        .select(
          "DATE(token_usages.created_at) as date",
          "SUM(input_tokens) as total_input",
          "SUM(output_tokens) as total_output",
          "SUM(cost) as total_cost",
          "COUNT(*) as usage_count"
        )
        .order("date")
    end

    # Per-board breakdown
    def by_board_breakdown
      joins(task: :board)
        .group("boards.id", "boards.name", "boards.icon")
        .select(
          "boards.id as board_id",
          "boards.name as board_name",
          "boards.icon as board_icon",
          "SUM(input_tokens) as total_input",
          "SUM(output_tokens) as total_output",
          "SUM(cost) as total_cost",
          "COUNT(*) as usage_count"
        )
        .order("total_cost DESC")
    end

    # Create from OpenClaw session data
    # Expects a hash with :input_tokens, :output_tokens, :model
    def record_from_session(task:, session_data:, session_key: nil)
      return nil unless session_data.is_a?(Hash)

      model = normalize_model_name(session_data[:model] || task.model)
      return nil unless model.present?

      create!(
        task: task,
        agent_persona_id: resolve_persona_id(task),
        model: model,
        input_tokens: session_data[:input_tokens].to_i,
        output_tokens: session_data[:output_tokens].to_i,
        session_key: session_key || task.agent_session_key
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[TokenUsage] Failed to record: #{e.message}")
      nil
    end

    private

    def normalize_model_name(model_str)
      return nil if model_str.blank?
      model_str = model_str.to_s.downcase

      # Map full model names to our simplified keys
      if model_str.include?("opus")
        "opus"
      elsif model_str.include?("sonnet")
        "sonnet"
      elsif model_str.include?("codex")
        "codex"
      elsif model_str.include?("gemini")
        "gemini"
      elsif model_str.include?("glm")
        "glm"
      else
        model_str.split("/").last.split("-").first  # best effort
      end
    end

    def resolve_persona_id(task)
      return nil unless task.respond_to?(:agent_persona_id)
      task.agent_persona_id
    rescue
      nil
    end
  end

  private

  def normalize_model(model_str)
    self.class.send(:normalize_model_name, model_str)
  end
end
