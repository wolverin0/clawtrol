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
end
