import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["flowsList", "runsList", "statsBar", "content", "toggleIcon", "badge"]
  static values = {
    apiBase: { type: String, default: "/api/v1" },
    interval: { type: Number, default: 15000 },
    collapsed: { type: Boolean, default: true }
  }

  connect() {
    this.token = document.querySelector('meta[name="api-token"]')?.content ||
                 document.querySelector('meta[name="csrf-token"]')?.content
    this.poll()
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    this.contentTarget.classList.toggle("hidden", this.collapsedValue)
    this.toggleIconTarget.classList.toggle("rotate-180", !this.collapsedValue)
  }

  async poll() {
    try {
      const headers = { "Accept": "application/json" }
      if (this.token) headers["Authorization"] = `Bearer ${this.token}`

      const [flowsRes, runsRes, statsRes] = await Promise.all([
        fetch(`${this.apiBaseValue}/openclaw_flows/active`, { headers }),
        fetch(`${this.apiBaseValue}/background_runs?status=running&limit=10`, { headers }),
        fetch(`${this.apiBaseValue}/background_runs/stats`, { headers })
      ])

      const flows = await flowsRes.json()
      const runs = await runsRes.json()
      const stats = await statsRes.json()

      this.renderFlows(flows)
      this.renderRuns(runs)
      this.renderStats(stats.today || stats)
      this.updateBadge(flows.length, runs.length)
    } catch (e) {
      console.warn("[active-flows] poll error:", e)
    }
  }

  updateBadge(flowCount, runCount) {
    const total = flowCount + runCount
    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = total
      this.badgeTarget.classList.toggle("hidden", total === 0)
    }
  }

  renderFlows(flows) {
    if (!this.hasFlowsListTarget) return
    if (flows.length === 0) {
      this.flowsListTarget.innerHTML = '<p class="text-xs text-content-muted italic">No active flows</p>'
      return
    }
    this.flowsListTarget.innerHTML = flows.map(f => `
      <div class="flex items-center justify-between px-3 py-1.5 rounded bg-bg-elevated text-xs">
        <div class="flex items-center gap-2 min-w-0">
          <span class="w-2 h-2 rounded-full bg-green-400 animate-pulse flex-shrink-0"></span>
          <span class="truncate text-content">${f.task_name || f.flow_id || 'Unnamed flow'}</span>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          ${f.model ? `<span class="text-content-muted">${f.model}</span>` : ''}
          ${f.duration_minutes != null ? `<span class="text-content-muted">${f.duration_minutes}m</span>` : ''}
        </div>
      </div>
    `).join('')
  }

  renderRuns(runs) {
    if (!this.hasRunsListTarget) return
    if (runs.length === 0) {
      this.runsListTarget.innerHTML = '<p class="text-xs text-content-muted italic">No running tasks</p>'
      return
    }
    const typeIcons = { cron: '⏰', subagent: '🤖', acp: '💻', manual: '👤' }
    this.runsListTarget.innerHTML = runs.map(r => `
      <div class="flex items-center justify-between px-3 py-1.5 rounded bg-bg-elevated text-xs">
        <div class="flex items-center gap-2 min-w-0">
          <span>${typeIcons[r.run_type] || '▶'}</span>
          <span class="truncate text-content">${r.label || r.run_id?.slice(0, 8) || 'Unknown'}</span>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          ${r.model ? `<span class="text-content-muted">${r.model}</span>` : ''}
          ${r.run_type ? `<span class="px-1.5 py-0.5 rounded bg-bg-surface text-content-muted">${r.run_type}</span>` : ''}
        </div>
      </div>
    `).join('')
  }

  renderStats(stats) {
    if (!this.hasStatsBarTarget) return
    this.statsBarTarget.innerHTML = `
      <span title="Total today">📊 ${stats.total || 0}</span>
      <span title="Running" class="text-green-400">▶ ${stats.running || 0}</span>
      <span title="Completed" class="text-content-muted">✅ ${stats.completed || 0}</span>
      ${stats.failed > 0 ? `<span title="Failed" class="text-red-400">❌ ${stats.failed}</span>` : ''}
      ${stats.total_cost > 0 ? `<span title="Cost today" class="text-content-muted">$${stats.total_cost.toFixed(2)}</span>` : ''}
    `
  }
}
