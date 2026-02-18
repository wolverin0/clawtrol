import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "grid", "summary", "selectAll", "batchToolbar", "selectionCount", "resultPanel", "resultContent",
    "broadcastModal", "broadcastPrompt", "agentCheckbox"
  ]
  static values = { refreshInterval: { type: Number, default: 15000 } }

  connect() {
    this.selected = new Set()
    this.refresh = this.refresh.bind(this)
    this.timer = setInterval(this.refresh, this.refreshIntervalValue)
    this.syncSelectionUi()
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

  toggleSelection(event) {
    const checkbox = event.currentTarget
    const agentId = checkbox.dataset.agentId
    if (!agentId) return

    if (checkbox.checked) this.selected.add(agentId)
    else this.selected.delete(agentId)

    this.syncSelectionUi()
  }

  toggleSelectAll() {
    const checked = this.selectAllTarget.checked
    const checkboxes = this.gridTarget.querySelectorAll('input[type="checkbox"][data-agent-id]')

    this.selected.clear()
    checkboxes.forEach((box) => {
      box.checked = checked
      if (checked) this.selected.add(box.dataset.agentId)
    })

    this.syncSelectionUi()
  }

  async refresh() {
    try {
      const response = await fetch("/zerobitch/metrics", { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const payload = await response.json()
      this.renderSummary(payload.summary || {})
      this.renderCards(payload.agents || [])
      this.restoreSelection()
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

    if (response.ok) await this.refresh()
  }

  batchStart() { this.runBatch("start_all") }
  batchStop() { this.runBatch("stop_all") }
  batchDelete() {
    if (!window.confirm("Delete selected agents?")) return
    this.runBatch("delete_all")
  }

  openBroadcastModal() {
    this.broadcastModalTarget.classList.remove("hidden")
    this.broadcastModalTarget.classList.add("flex")
  }

  closeBroadcastModal() {
    this.broadcastModalTarget.classList.add("hidden")
    this.broadcastModalTarget.classList.remove("flex")
  }

  sendBroadcast() {
    const prompt = this.broadcastPromptTarget.value.trim()
    if (!prompt) return

    this.runBatch("broadcast", prompt)
    this.broadcastPromptTarget.value = ""
    this.closeBroadcastModal()
  }

  async runBatch(action, prompt = "") {
    if (this.selected.size === 0) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const body = { batch_action: action, agent_ids: Array.from(this.selected), prompt }

    const response = await fetch("/zerobitch/batch", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        Accept: "application/json"
      },
      body: JSON.stringify(body)
    })

    if (!response.ok) return

    const payload = await response.json()
    this.renderBatchResults(payload)
    await this.refresh()
  }

  renderBatchResults(payload) {
    this.resultPanelTarget.classList.remove("hidden")

    const lines = [
      `Action: ${payload.batch_action || payload.action}`,
      `Total: ${payload.total} | OK: ${payload.ok} | Failed: ${payload.failed}`,
      ""
    ]

    ;(payload.results || []).forEach((entry) => {
      lines.push(`${entry.success ? "✅" : "❌"} ${entry.id}`)
      if (entry.error) lines.push(`  Error: ${entry.error}`)
      if (entry.output) lines.push(`  Output: ${String(entry.output).slice(0, 240)}`)
    })

    this.resultContentTarget.textContent = lines.join("\n")
  }

  renderSummary(summary) {
    if (!this.hasSummaryTarget) return
    const set = (key, val) => {
      const el = this.summaryTarget.querySelector(`[data-summary-key="${key}"]`)
      if (el) el.textContent = val ?? "0"
    }
    set("total", summary.total)
    set("running", summary.running)
    set("stopped", summary.stopped)
    set("total_ram", summary.total_ram)
    set("avg_ram_percent", summary.avg_ram_percent)
    set("tasks_today", summary.tasks_today)
  }

  renderSparkline(points) {
    if (!points || points.length < 2) return ""
    const max = Math.max(...points, 1)
    const coords = points.map((v, i) => {
      const x = (i / (points.length - 1) * 120).toFixed(1)
      const y = (24 - (v / max) * 22).toFixed(1)
      return `${x},${y}`
    }).join(" ")
    return `
      <div class="mt-3 space-y-1" data-action="click->zerobitch-fleet#consumeClick">
        <div class="text-[10px] text-content-muted">Memory (1h)</div>
        <svg viewBox="0 0 120 24" class="w-full h-6 text-accent" preserveAspectRatio="none">
          <polyline fill="none" stroke="currentColor" stroke-width="1.5" points="${coords}" />
        </svg>
      </div>`
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
            <div class="flex items-start gap-2 min-w-0">
              <input type="checkbox" class="mt-1 rounded border-border bg-bg-base" data-action="click->zerobitch-fleet#consumeClick change->zerobitch-fleet#toggleSelection" data-agent-id="${agent.id}">
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <span class="text-xl">${agent.emoji || "🤖"}</span>
                  <h3 class="text-sm font-semibold text-content truncate">${this.escapeHtml(agent.name || "Agent")}</h3>
                </div>
                <p class="text-xs text-content-muted mt-1 truncate">${this.escapeHtml(agent.role || "")}</p>
              </div>
            </div>
            <span class="px-2 py-0.5 rounded-full text-xs font-medium border ${badge}">${this.escapeHtml(agent.status_label || "Stopped")}</span>
          </div>

          <div class="mt-3 space-y-1 text-xs text-content-muted">
            <p><span class="text-content-secondary">Provider:</span> ${this.escapeHtml(agent.provider || "")}</p>
            <p class="truncate"><span class="text-content-secondary">Model:</span> ${this.escapeHtml(agent.model || "")}</p>
            <p><span class="text-content-secondary">RAM:</span> ${this.escapeHtml(agent.ram_usage || "—")}</p>
            <div>
              <div class="w-full h-1.5 bg-bg-base rounded-full overflow-hidden border border-border/50">
                <div class="h-full bg-accent" style="width: ${agent.ram_percent || 0}%"></div>
              </div>
              <p class="mt-1 text-[11px]">Usage: ${agent.ram_percent || 0}% of ${this.escapeHtml(agent.ram_limit || "—")}</p>
            </div>
            <p><span class="text-content-secondary">Uptime:</span> ${this.escapeHtml(agent.uptime || "—")}</p>
            <p><span class="text-content-secondary">Last Activity:</span> ${this.escapeHtml(agent.last_activity || "No tasks yet")}</p>
          </div>

          <div class="mt-4 grid grid-cols-2 gap-2" data-action="click->zerobitch-fleet#consumeClick">
            ${this.actionButton(agent.id, "start", "▶️ Start", "bg-green-600/80 hover:bg-green-500")}
            ${this.actionButton(agent.id, "stop", "⏹ Stop", "bg-yellow-600/80 hover:bg-yellow-500")}
            ${this.actionButton(agent.id, "restart", "🔄 Restart", "bg-orange-600/80 hover:bg-orange-500")}
            ${this.actionButton(agent.id, "delete", "🗑 Delete", "bg-red-700/80 hover:bg-red-600")}
          </div>

          ${this.renderSparkline(agent.sparkline_mem || [])}
          <a href="${agent.detail_path}" class="mt-3 inline-flex w-full items-center justify-center rounded-md px-3 py-2 text-sm font-medium bg-accent hover:opacity-90 text-white" data-action="click->zerobitch-fleet#consumeClick">Send Task</a>
        </div>
      `
    }).join("")
  }

  restoreSelection() {
    const checkboxes = this.gridTarget.querySelectorAll('input[type="checkbox"][data-agent-id]')
    const visibleIds = new Set()

    checkboxes.forEach((box) => {
      const id = box.dataset.agentId
      visibleIds.add(id)
      box.checked = this.selected.has(id)
    })

    this.selected.forEach((id) => {
      if (!visibleIds.has(id)) this.selected.delete(id)
    })

    this.syncSelectionUi()
  }

  syncSelectionUi() {
    const count = this.selected.size
    if (this.hasSelectionCountTarget) this.selectionCountTarget.textContent = String(count)
    if (this.hasBatchToolbarTarget) this.batchToolbarTarget.classList.toggle("hidden", count === 0)

    const checkboxes = this.gridTarget.querySelectorAll('input[type="checkbox"][data-agent-id]')
    const allChecked = checkboxes.length > 0 && Array.from(checkboxes).every((box) => box.checked)
    this.selectAllTarget.checked = allChecked
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
