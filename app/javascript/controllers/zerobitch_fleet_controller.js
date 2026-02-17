import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "summary"]
  static values = { refreshInterval: { type: Number, default: 15000 } }

  connect() {
    this.refresh = this.refresh.bind(this)
    this.timer = setInterval(this.refresh, this.refreshIntervalValue)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  consumeClick(event) {
    event.stopPropagation()
  }

  openAgent(event) {
    const card = event.currentTarget
    const link = card.querySelector("a[href]")
    if (link) window.location.href = link.href
  }

  async refresh() {
    try {
      const response = await fetch("/zerobitch?format=json", { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const payload = await response.json()
      this.renderSummary(payload.summary || {})
      this.renderCards(payload.agents || [])
    } catch (_error) {
      // silent polling fail
    }
  }

  async invokeAction(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const agentId = button.dataset.agentId
    const command = button.dataset.command
    if (!agentId || !command) return

    if (command === "delete" && !window.confirm(`Delete agent ${agentId}?`)) return

    const path = command === "delete"
      ? `/zerobitch/agents/${encodeURIComponent(agentId)}`
      : `/zerobitch/agents/${encodeURIComponent(agentId)}/${command}`

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    const response = await fetch(path, {
      method: command === "delete" ? "DELETE" : "POST",
      headers: {
        "X-CSRF-Token": token,
        Accept: "application/json"
      }
    })

    if (response.ok) {
      await this.refresh()
    }
  }

  renderSummary(summary) {
    if (!this.hasSummaryTarget) return
    this.summaryTarget.querySelector('[data-summary-key="total"]').textContent = summary.total ?? "0"
    this.summaryTarget.querySelector('[data-summary-key="running"]').textContent = summary.running ?? "0"
    this.summaryTarget.querySelector('[data-summary-key="stopped"]').textContent = summary.stopped ?? "0"
    this.summaryTarget.querySelector('[data-summary-key="total_ram"]').textContent = summary.total_ram ?? "0 MiB"
  }

  renderCards(agents) {
    if (!this.hasGridTarget) return

    this.gridTarget.innerHTML = agents.map((agent) => {
      const badge = this.statusBadgeClasses(agent.status)
      return `
        <div class="group bg-bg-elevated border border-border rounded-xl p-4 hover:border-accent/40 transition-colors cursor-pointer"
             data-agent-id="${agent.id}"
             data-action="click->zerobitch-fleet#openAgent">
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-xl">${agent.emoji || "🤖"}</span>
                <h3 class="text-sm font-semibold text-content truncate">${this.escapeHtml(agent.name || "Agent")}</h3>
              </div>
              <p class="text-xs text-content-muted mt-1 truncate">${this.escapeHtml(agent.role || "")}</p>
            </div>
            <span class="px-2 py-0.5 rounded-full text-xs font-medium border ${badge}">${this.escapeHtml(agent.status_label || "Stopped")}</span>
          </div>

          <div class="mt-3 space-y-1 text-xs text-content-muted">
            <p><span class="text-content-secondary">Provider:</span> ${this.escapeHtml(agent.provider || "")}</p>
            <p class="truncate"><span class="text-content-secondary">Model:</span> ${this.escapeHtml(agent.model || "")}</p>
            <p><span class="text-content-secondary">RAM:</span> ${this.escapeHtml(agent.ram_usage || "—")}</p>
            <p><span class="text-content-secondary">Uptime:</span> ${this.escapeHtml(agent.uptime || "—")}</p>
          </div>

          <div class="mt-4 grid grid-cols-2 gap-2" data-action="click->zerobitch-fleet#consumeClick">
            ${this.actionButton(agent.id, "start", "▶️ Start", "bg-green-600/80 hover:bg-green-500")}
            ${this.actionButton(agent.id, "stop", "⏹ Stop", "bg-yellow-600/80 hover:bg-yellow-500")}
            ${this.actionButton(agent.id, "restart", "🔄 Restart", "bg-orange-600/80 hover:bg-orange-500")}
            ${this.actionButton(agent.id, "delete", "🗑 Delete", "bg-red-700/80 hover:bg-red-600")}
          </div>

          <a href="${agent.detail_path}" class="mt-3 inline-flex w-full items-center justify-center rounded-md px-3 py-2 text-sm font-medium bg-accent hover:opacity-90 text-white" data-action="click->zerobitch-fleet#consumeClick">Send Task</a>
        </div>
      `
    }).join("")
  }

  actionButton(agentId, command, label, colorClasses) {
    return `<button type="button" class="px-2 py-1.5 rounded-md text-xs ${colorClasses} text-white" data-command="${command}" data-agent-id="${agentId}" data-action="click->zerobitch-fleet#invokeAction">${label}</button>`
  }

  statusBadgeClasses(status) {
    if (status === "running") return "bg-emerald-500/15 text-emerald-400 border-emerald-500/30"
    if (status === "restarting") return "bg-yellow-500/15 text-yellow-300 border-yellow-500/30"
    return "bg-red-500/15 text-red-400 border-red-500/30"
  }

  escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }
}
