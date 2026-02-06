module AgentPersonasHelper
  # Determine agent status: working, rate_limited, or idle
  def agent_status(persona, active_tasks_count, rate_limited_models)
    if rate_limited_models.include?(persona.model)
      :rate_limited
    elsif active_tasks_count > 0
      :working
    else
      :idle
    end
  end

  def agent_status_class(status)
    case status
    when :working
      "bg-accent/20 text-accent border-accent/30"
    when :rate_limited
      "bg-red-500/20 text-red-400 border-red-500/30"
    when :idle
      "bg-bg-elevated text-content-muted border-border"
    end
  end

  def agent_status_icon(status)
    case status
    when :working then "⚡"
    when :rate_limited then "🚫"
    when :idle then "💤"
    end
  end

  def agent_status_text(status)
    case status
    when :working then "Working"
    when :rate_limited then "Rate Limited"
    when :idle then "Idle"
    end
  end

  def agent_status_dot_class(status)
    case status
    when :working then "bg-green-500 animate-pulse"
    when :rate_limited then "bg-red-500"
    when :idle then "bg-gray-500"
    end
  end
end
