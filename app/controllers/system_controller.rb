class SystemController < ApplicationController
  before_action :require_authentication

  def index
    @stats = collect_system_stats
    @api_stats = collect_api_stats
  end

  private

  def collect_api_stats
    output = `openclaw status --json`.strip
    data = JSON.parse(output) rescue nil
    return {} unless data

    usage = data.dig('usage') || {}
    limits = data.dig('limits') || {}

    # Map providers to a consistent format
    {
      anthropic: format_provider_stats(usage, limits, 'anthropic'),
      google: format_provider_stats(usage, limits, 'google-gemini-cli'),
      openai: format_provider_stats(usage, limits, 'openai-codex')
    }
  end

  def format_provider_stats(usage, limits, provider_key)
    u = usage[provider_key] || {}
    l = limits[provider_key] || {}
    
    # Simple percentage calculation if limits are available
    tokens_percent = 0
    if l['tokens_limit'] && l['tokens_limit'] > 0
      tokens_percent = ((u['tokens_used'].to_f / l['tokens_limit']) * 100).round(1)
    end

    {
      used: u['tokens_used'] || 0,
      limit: l['tokens_limit'] || 'N/A',
      percent: tokens_percent,
      requests: u['requests_used'] || 0
    }
  end

  def collect_system_stats
    {
      cpu: cpu_usage,
      memory: memory_stats,
      disk: disk_usage,
      load_avg: os_load_avg
    }
  end

  def cpu_usage
    # Simple CPU usage from top/ps or similar
    output = `top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/" | awk '{print 100 - $1}'`.strip
    output.to_f.round(1) rescue 0.0
  end

  def memory_stats
    # free -m output: total, used, free, shared, buff/cache, available
    output = `free -m | grep Mem:`.split(/\s+/)
    total = output[1].to_i
    used = output[2].to_i
    percent = total > 0 ? ((used.to_f / total) * 100).round(1) : 0
    { total: total, used: used, percent: percent }
  rescue StandardError
    { total: 0, used: 0, percent: 0 }
  end

  def disk_usage
    output = `df / --output=pcent,used,size -B1M | tail -1`.split(/\s+/)
    percent = output[0].to_i
    used = output[1].to_i
    total = output[2].to_i
    { percent: percent, used: used, total: total }
  rescue StandardError
    { percent: 0, used: 0, total: 0 }
  end

  def os_load_avg
    load_avg = `cat /proc/loadavg`.split(/\s+/).first(3)
    { '1m': load_avg[0], '5m': load_avg[1], '15m': load_avg[2] }
  rescue StandardError
    { '1m': '0.00', '5m': '0.00', '15m': '0.00' }
  end
end
