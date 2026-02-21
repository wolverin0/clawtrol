# frozen_string_literal: true

module ApplicationHelper
  def status_badge_class(status)
    case status.to_s
    when "inbox"
      "bg-bg-base text-content-muted"
    when "up_next"
      "bg-blue-500/20 text-blue-400"
    when "in_progress"
      "bg-accent/20 text-accent"
    when "in_review"
      "bg-yellow-500/20 text-yellow-400"
    when "done"
      "bg-green-500/20 text-green-400"
    when "archived"
      "bg-bg-base text-content-muted"
    else
      "bg-bg-base text-content-muted"
    end
  end

  def activity_icon_bg(activity)
    case activity.action
    when "created"
      "bg-status-info/20"
    when "moved"
      "bg-purple-900/30"
    when "updated"
      "bg-status-warning/20"
    else
      "bg-bg-elevated"
    end
  end

  def activity_icon(activity)
    case activity.action
    when "created"
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-status-info"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>'.html_safe
    when "moved"
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-purple-400"><path stroke-linecap="round" stroke-linejoin="round" d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" /></svg>'.html_safe
    when "updated"
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-status-warning"><path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Z" /></svg>'.html_safe
    else
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-content-secondary"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>'.html_safe
    end
  end

  def app_base_url
    Rails.application.config.app_base_url.chomp("/")
  end

  def file_viewer_url(relative_path)
    "#{app_base_url}/view?file=#{relative_path}"
  end

  def pipeline_ui_enabled?(_user = current_user)
    false
  end

  def model_select_options(user = current_user, include_default: true)
    ids = ModelCatalogService.new(user).model_ids
    options = ids.map { |id| [model_display_name(id), id] }
    include_default ? [["Default", ""]] + options : options
  rescue StandardError
    fallback = Task::MODELS.map { |m| [model_display_name(m), m] }
    include_default ? [["Default", ""]] + fallback : fallback
  end

  def categorize_persona(persona)
    case persona.tier
    when 'strategic-reasoning' then 'review'
    when 'fast-coding' then 'dev'
    when 'research' then 'research'
    when 'operations' then 'ops'
    end ||
    case persona.name.downcase
    when /dev|frontend|backend|architect|dashboard|whatsapp/ then 'dev'
    when /review|verifier|security|checker|tdd/ then 'review'
    when /research|roadmap|synthesizer|mapper/ then 'research'
    when /executor|runner|ops|updater|build|error|refactor|doc|clean/ then 'ops'
    when /plan|debug|summar/ then 'ops'
    else 'ops'
    end
  end

  def grouped_agent_personas(personas)
    categories = {
      'dev'      => { icon: '💻', label: 'Dev',      color: 'blue',    personas: [] },
      'ops'      => { icon: '🔧', label: 'Ops',      color: 'orange',  personas: [] },
      'research' => { icon: '🔍', label: 'Research', color: 'emerald', personas: [] },
      'review'   => { icon: '✅', label: 'Review',   color: 'purple',  personas: [] }
    }
    personas.each do |persona|
      cat = categorize_persona(persona)
      categories[cat][:personas] << persona if categories[cat]
    end
    categories.reject { |_, v| v[:personas].empty? }
  end

  def model_display_name(model_id)
    id = model_id.to_s
    return id if id.blank?

    return id.upcase if id.match?(/\A(opus|codex|glm|grok)\z/i)
    return "Gemini" if id.casecmp("gemini").zero?
    return "Sonnet" if id.casecmp("sonnet").zero?

    id
  end
end
