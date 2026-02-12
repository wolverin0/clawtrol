module CronjobsHelper
  DAY_NAMES = {
    "0" => "Sunday",
    "1" => "Monday",
    "2" => "Tuesday",
    "3" => "Wednesday",
    "4" => "Thursday",
    "5" => "Friday",
    "6" => "Saturday",
    "7" => "Sunday"
  }.freeze

  def humanize_openclaw_schedule(schedule)
    schedule = schedule || {}
    kind = schedule["kind"].to_s

    case kind
    when "every"
      every_ms = schedule["everyMs"].to_i
      return "Every ?" if every_ms <= 0
      "Every #{humanize_duration_ms(every_ms)}"
    when "cron"
      expr = schedule["expr"].to_s.strip
      tz = schedule["tz"].presence
      text = humanize_cron_expr(expr)
      tz ? "#{text} (#{tz})" : text
    else
      kind.present? ? kind : "(unscheduled)"
    end
  end

  def humanize_cron_expr(expr)
    parts = expr.to_s.split
    return expr if parts.length < 5

    min, hour, dom, mon, dow = parts.first(5)

    # Very small, opinionated subset — good enough for our known jobs.
    if dom == "*" && mon == "*" && dow == "*" && min.match?(/\A\d+\z/) && hour.match?(/\A\d+\z/)
      return "Daily at #{format_hour_min(hour.to_i, min.to_i)}"
    end

    if dom == "*" && mon == "*" && dow.match?(/\A\d+\z/) && min.match?(/\A\d+\z/) && hour.match?(/\A\d+\z/)
      day = DAY_NAMES[dow] || "Day #{dow}"
      return "#{day}s at #{format_hour_min(hour.to_i, min.to_i)}"
    end

    if min.start_with?("*/") && hour == "*" && dom == "*" && mon == "*" && dow == "*"
      n = min.delete_prefix("*/").to_i
      return "Every #{n} minutes" if n > 0
    end

    expr
  end

  def humanize_duration_ms(ms)
    seconds = (ms.to_f / 1000.0).round

    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{(seconds / 60.0).round}m"
    elsif seconds < 86_400
      hours = (seconds / 3600.0)
      hours.to_i == hours ? "#{hours.to_i}h" : format("%.1fh", hours)
    else
      days = (seconds / 86_400.0)
      days.to_i == days ? "#{days.to_i}d" : format("%.1fd", days)
    end
  end

  def format_hour_min(hour, min)
    t = Time.utc(2000, 1, 1, hour, min)
    t.strftime("%-I:%M %p")
  rescue StandardError
    format("%02d:%02d", hour, min)
  end
end
