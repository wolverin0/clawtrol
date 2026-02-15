# frozen_string_literal: true

# Extracts board task analysis + AgentPersona generation from BoardsController.
# Analyzes a board's tasks to auto-generate an appropriate agent persona.
class PersonaGeneratorService
  Result = Struct.new(:success?, :persona, :error, keyword_init: true)

  TIER_CODING_TAGS = %w[bug fix code feature refactor].freeze
  TIER_RESEARCH_TAGS = %w[research analysis report].freeze
  TIER_OPS_TAGS = %w[ops infra deploy network].freeze

  def initialize(board:, user:)
    @board = board
    @user = user
  end

  def call
    tasks = @board.tasks

    analysis = analyze_tasks(tasks)
    tier = determine_tier(analysis[:common_tags])
    system_prompt = build_system_prompt(analysis)

    persona = AgentPersona.find_or_initialize_by(board_id: @board.id, auto_generated: true)
    persona.assign_attributes(
      user: @user,
      name: "#{@board.name.parameterize}-agent",
      description: "Auto-generated persona for #{@board.name} board (#{analysis[:total]} tasks analyzed)",
      system_prompt: system_prompt,
      model: analysis[:preferred_model],
      tier: tier,
      tools: AgentPersona::DEFAULT_TOOLS,
      auto_generated: true,
      active: true,
      emoji: @board.icon.presence || "🤖"
    )

    if persona.save
      Result.new(success?: true, persona: persona)
    else
      Result.new(success?: false, error: persona.errors.full_messages.join(", "))
    end
  end

  private

  def analyze_tasks(tasks)
    status_counts = tasks.group(:status).count
    total = tasks.count

    recent_tasks = tasks.order(created_at: :desc).limit(10).pluck(:name, :description).map do |name, description|
      [name.to_s.truncate(200), description.to_s.truncate(200)]
    end

    common_tags = tasks.where.not(tags: nil)
      .where("array_length(tags, 1) > 0")
      .pluck(Arel.sql("unnest(tags)"))
      .compact
      .map(&:to_s)
      .reject(&:blank?)
      .tally
      .sort_by { |_, count| -count }
      .first(10)
      .to_h

    model_counts = tasks.where.not(model: [nil, ""]).group(:model).count
    preferred_model = model_counts.max_by { |_, count| count }&.first || "sonnet"

    error_tasks = tasks.where.not(error_message: [nil, ""])
      .order(updated_at: :desc)
      .limit(5)
      .pluck(:name, :error_message)

    {
      status_counts: status_counts,
      total: total,
      recent_tasks: recent_tasks,
      common_tags: common_tags,
      preferred_model: preferred_model,
      error_tasks: error_tasks
    }
  end

  def determine_tier(common_tags)
    tag_list = common_tags.keys.map(&:downcase)
    if (tag_list & TIER_CODING_TAGS).any?
      "fast-coding"
    elsif (tag_list & TIER_RESEARCH_TAGS).any?
      "research"
    elsif (tag_list & TIER_OPS_TAGS).any?
      "operations"
    else
      "strategic-reasoning"
    end
  end

  def build_system_prompt(analysis)
    prompt = +"# #{@board.name} Board Agent\n\n"
    prompt << "You are a specialized agent for the #{@board.name} board.\n\n"

    prompt << "## Board Overview\n"
    prompt << "- Total tasks analyzed: #{analysis[:total]}\n"
    analysis[:status_counts].each { |status, count| prompt << "- #{status}: #{count}\n" }
    prompt << "\n"

    if analysis[:common_tags].any?
      prompt << "## Common Task Types\n"
      analysis[:common_tags].each { |tag, count| prompt << "- #{tag} (#{count} tasks)\n" }
      prompt << "\n"
    end

    if analysis[:recent_tasks].any?
      prompt << "## Recent Task Patterns\n"
      analysis[:recent_tasks].first(5).each do |name, description|
        prompt << "- **#{name}**"
        prompt << ": #{description.to_s.truncate(150)}" if description.present?
        prompt << "\n"
      end
      prompt << "\n"
    end

    if analysis[:error_tasks].any?
      prompt << "## Common Mistakes to Avoid\n"
      prompt << "Based on past failures:\n"
      analysis[:error_tasks].each do |name, error|
        prompt << "- #{name}: #{error.to_s.truncate(200)}\n"
      end
      prompt << "\n"
    end

    prompt << "## Preferred Model: #{analysis[:preferred_model]}\n"
    prompt
  end
end
