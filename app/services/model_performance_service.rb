# frozen_string_literal: true

# ModelPerformanceService analyzes task completion data by model
# to produce performance reports and routing recommendations.
#
# Usage:
#   service = ModelPerformanceService.new(user, period: 30.days)
#   report = service.report
#   summary = service.summary
#
class ModelPerformanceService
  # Map long model identifiers to short canonical names
  MODEL_ALIASES = {
    "opus"   => %w[opus claude-opus anthropic/claude-opus],
    "sonnet" => %w[sonnet claude-sonnet anthropic/claude-sonnet],
    "codex"  => %w[codex gpt-5.3-codex openai-codex/gpt-5.3-codex],
    "gemini" => %w[gemini gemini-2.5-pro google-gemini-cli/gemini-2.5-pro gemini-3-pro-preview google-gemini-cli/gemini-3-pro-preview],
    "glm"    => %w[glm glm-4.7 zai/glm-4.7]
  }.freeze

  DEFAULT_PERIOD = 30.days

  def initialize(user, period: DEFAULT_PERIOD)
    @user = user
    @period = period
  end

  # Full performance report
  def report
    tasks = completed_tasks
    by_model = group_by_model(tasks)
    by_type = group_by_task_type(tasks)

    {
      period_days: (@period / 1.day).to_i,
      total_tasks: tasks.size,
      by_model: by_model,
      by_task_type: by_type,
      recommendations: build_recommendations(by_model, tasks),
      generated_at: Time.current.iso8601
    }
  end

  # Quick summary for dashboard widgets
  def summary
    tasks = completed_tasks
    by_model = group_by_model(tasks)

    best = by_model.max_by { |_, stats| stats[:success_rate] }

    {
      total_tasks: tasks.size,
      models_used: by_model.keys.size,
      best_model: best&.first,
      best_success_rate: best&.last&.dig(:success_rate) || 0.0,
      total_cost: total_cost(tasks)
    }
  end

  private

  def completed_tasks
    @completed_tasks ||= @user.tasks
      .where("completed_at >= ? OR (status IN (?) AND updated_at >= ?)",
             @period.ago, [Task.statuses[:done], Task.statuses[:in_review]], @period.ago)
      .where.not(status: :archived)
      .to_a
  end

  def group_by_model(tasks)
    groups = tasks.group_by { |t| normalize_model(t.model) }.compact_blank

    groups.transform_values do |model_tasks|
      succeeded = model_tasks.select { |t| t.status == "done" }
      failed = model_tasks.select { |t| t.error_message.present? }

      {
        total: model_tasks.size,
        succeeded: succeeded.size,
        failed: failed.size,
        success_rate: success_rate(model_tasks),
        avg_completion_time: avg_completion_time(succeeded),
        error_rate: model_tasks.size > 0 ? (failed.size.to_f / model_tasks.size * 100).round(1) : 0.0
      }
    end
  end

  def group_by_task_type(tasks)
    groups = {}

    tasks.each do |task|
      types = task.tags.presence || ["untagged"]
      types.each do |tag|
        groups[tag] ||= []
        groups[tag] << task
      end
    end

    groups.transform_values do |type_tasks|
      {
        total: type_tasks.size,
        success_rate: success_rate(type_tasks),
        models_used: type_tasks.map { |t| normalize_model(t.model) }.compact.uniq
      }
    end
  end

  def build_recommendations(by_model, tasks)
    recs = []

    # High error rate warning
    by_model.each do |model, stats|
      if stats[:error_rate] > 30 && stats[:total] >= 3
        recs << {
          type: "high_error_rate",
          severity: "high",
          message: "#{model} has a #{stats[:error_rate]}% error rate over #{stats[:total]} tasks. Consider switching to a different model for these task types."
        }
      end
    end

    # Low utilization warning
    by_model.each do |model, stats|
      if stats[:total] <= 1 && tasks.size > 5
        recs << {
          type: "low_utilization",
          severity: "low",
          message: "#{model} was used for only #{stats[:total]} task(s). Consider using it more if it performs well, or remove from rotation."
        }
      end
    end

    # Single model dependency
    if by_model.size == 1 && tasks.size > 5
      recs << {
        type: "single_model_dependency",
        severity: "medium",
        message: "All #{tasks.size} tasks used #{by_model.keys.first}. Consider diversifying models for resilience."
      }
    end

    recs
  end

  def normalize_model(model_str)
    return nil if model_str.blank?

    downcase = model_str.to_s.downcase.strip

    MODEL_ALIASES.each do |canonical, variants|
      return canonical if variants.any? { |v| downcase.include?(v.downcase) }
    end

    # Unknown model: return last segment (after /)
    downcase.include?("/") ? downcase.split("/").last : downcase
  end

  def success_rate(tasks)
    return 0.0 if tasks.empty?
    succeeded = tasks.count { |t| t.status == "done" }
    (succeeded.to_f / tasks.size * 100).round(1)
  end

  def avg_completion_time(tasks)
    times = tasks.filter_map do |t|
      next unless t.completed_at && t.created_at
      t.completed_at - t.created_at
    end
    return nil if times.empty?
    (times.sum / times.size).round(0)
  end

  def total_cost(tasks)
    # Sum token_usages cost for these tasks if available
    task_ids = tasks.map(&:id)
    return 0.0 if task_ids.empty?

    TokenUsage.where(task_id: task_ids).sum(:cost).to_f.round(4)
  end
end
