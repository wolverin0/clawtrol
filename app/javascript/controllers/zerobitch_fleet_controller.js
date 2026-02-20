import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "grid", "summary", "selectAll", "batchToolbar", "selectionCount", "resultPanel", "resultContent",
    "broadcastModal", "broadcastPrompt", "agentCheckbox",
    "logsModal", "logsTitle", "logsTail", "logsStatus", "logsOutput"
  ]
  static values = { refreshInterval: { type: Number, default: 15000 } }

  connect() {
    this.selected = new Set()
    this.dirtyTemplates = new Map()
    this.onTemplateInput = this.onTemplateInput.bind(this)
    this.refresh = this.refresh.bind(this)
    this.timer = setInterval(this.refresh, this.refreshIntervalValue)
    this.syncSelectionUi()
    if (this.hasGridTarget) {
      this.gridTarget.addEventListener("input", this.onTemplateInput)
    }
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
    if (this.hasGridTarget) {
      this.gridTarget.removeEventListener("input", this.onTemplateInput)
    }
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
      if (this.isTemplateFocused()) return
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

  openLogs(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const card = button.closest("[data-agent-id]")
    const agentId = button.dataset.agentId || card?.dataset.agentId
    if (!agentId) return

    const agentName = button.dataset.agentName || card?.dataset.agentName || agentId
    this.logsAgentId = agentId
    this.logsAgentName = agentName

    if (this.hasLogsTitleTarget) {
      this.logsTitleTarget.textContent = `Logs · ${agentName}`
    }

    this.logsModalTarget.classList.remove("hidden")
    this.logsModalTarget.classList.add("flex")
    this.refreshLogs()
  }

  closeLogs() {
    this.logsModalTarget.classList.add("hidden")
    this.logsModalTarget.classList.remove("flex")
    if (this.hasLogsStatusTarget) this.logsStatusTarget.textContent = ""
  }

  async refreshLogs() {
    if (!this.logsAgentId) return

    const tail = parseInt(this.logsTailTarget.value || "200", 10)
    if (this.hasLogsStatusTarget) this.logsStatusTarget.textContent = "Loading..."

    try {
      const response = await fetch(`/zerobitch/agents/${encodeURIComponent(this.logsAgentId)}/logs?tail=${tail}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      const payload = await response.json()
      this.logsOutputTarget.textContent = payload.output || payload.error || "(no logs)"
      if (this.hasLogsStatusTarget) {
        this.logsStatusTarget.textContent = `Updated ${new Date().toLocaleTimeString()}`
      }
    } catch (error) {
      this.logsOutputTarget.textContent = `Failed to load logs: ${error.message}`
      if (this.hasLogsStatusTarget) this.logsStatusTarget.textContent = "Failed"
    }
  }

  async saveTemplate(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const card = button.closest("[data-agent-id]")
    const agentId = button.dataset.agentId || card?.dataset.agentId
    if (!agentId || !card) return

    const textarea = card.querySelector("textarea[data-template-editor]")
    const status = card.querySelector("[data-template-status]")
    if (!textarea) return

    if (status) status.textContent = "Saving..."

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(`/zerobitch/agents/${encodeURIComponent(agentId)}/template`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          Accept: "application/json"
        },
        body: JSON.stringify({ template: textarea.value })
      })

      if (!response.ok) {
        const payload = await response.json()
        throw new Error(payload.error || `HTTP ${response.status}`)
      }

      this.dirtyTemplates.delete(agentId)
      if (status) {
        status.textContent = "Saved"
        window.setTimeout(() => {
          if (status.textContent === "Saved") status.textContent = ""
        }, 1500)
      }
    } catch (error) {
      if (status) status.textContent = `Error: ${error.message}`
    }
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

    const visibleIds = new Set(agents.map((agent) => String(agent.id)))
    this.dirtyTemplates.forEach((_value, agentId) => {
      if (!visibleIds.has(agentId)) this.dirtyTemplates.delete(agentId)
    })

    this.gridTarget.innerHTML = agents.map((agent) => {
      const badge = this.statusBadgeClasses(agent.status)
      const cronEntries = Array.isArray(agent.cron_display) ? agent.cron_display : (agent.cron_display ? [agent.cron_display] : [])
      const cronLabel = agent.cron_source === "native" ? "native" : "registry"
      const cronHtml = cronEntries.length
        ? `
          <div class="mt-1 text-[11px] text-emerald-300">
            <div>⏱ Cron (${cronLabel}):</div>
            ${cronEntries.map((entry) => `<div class="truncate">${this.escapeHtml(entry)}</div>`).join("")}
          </div>`
        : ""
      const descriptionHtml = agent.description
        ? `<p class="text-[11px] text-content-muted mt-1 line-clamp-2">${this.escapeHtml(agent.description)}</p>`
        : ""
      const skillforgeBadge = agent.skillforge
        ? `<span class="text-[10px] px-1.5 py-0.5 rounded-full border border-indigo-500/40 bg-indigo-500/10 text-indigo-200">Skillforge</span>`
        : ""
      const ramPercent = agent.ram_percent ?? null
      const ramPercentLabel = ramPercent !== null && ramPercent !== undefined ? `${ramPercent}%` : "—"
      const ramPercentWidth = ramPercent || 0
      const restartCount = agent.restart_count ?? "—"
      const agentId = String(agent.id)
      const hasDirtyTemplate = this.dirtyTemplates.has(agentId)
      const templateValue = hasDirtyTemplate ? this.dirtyTemplates.get(agentId) : (agent.template ?? "")
      const templateStatus = hasDirtyTemplate ? "Unsaved" : ""
      const observability = agent.observability || {}
      const obsBackend = observability.backend || "—"
      const obsDetails = Object.entries(observability)
        .filter(([key]) => key !== "backend")
        .map(([key, value]) => `${key}=${value}`)
        .join(" · ")
      return `
        <div class="group bg-bg-elevated border border-border rounded-xl p-4 hover:border-accent/40 transition-colors cursor-pointer"
             data-agent-id="${agentId}"
             data-agent-name="${this.escapeHtml(agent.name || "Agent")}"
             data-action="click->zerobitch-fleet#openAgent">
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-start gap-2 min-w-0">
              <input type="checkbox" class="mt-1 rounded border-border bg-bg-base" data-action="click->zerobitch-fleet#consumeClick change->zerobitch-fleet#toggleSelection" data-agent-id="${agentId}">
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <span class="text-xl">${agent.emoji || "🤖"}</span>
                  <h3 class="text-sm font-semibold text-content truncate">${this.escapeHtml(agent.name || "Agent")}</h3>
                  ${skillforgeBadge}
                </div>
                <p class="text-xs text-content-muted mt-1 truncate">${this.escapeHtml(agent.role || "")}</p>
                ${descriptionHtml}
                ${cronHtml}
              </div>
            </div>
            <span class="px-2 py-0.5 rounded-full text-xs font-medium border ${badge}">${this.escapeHtml(agent.status_label || "Stopped")}</span>
          </div>

          <div class="mt-3 space-y-1 text-xs text-content-muted">
            <p><span class="text-content-secondary">Provider:</span> ${this.escapeHtml(agent.provider || "")}</p>
            <p class="truncate"><span class="text-content-secondary">Model:</span> ${this.escapeHtml(agent.model || "")}</p>
            <p><span class="text-content-secondary">Docker:</span> ${this.escapeHtml(agent.status_label || "Unknown")} · Restarts: ${this.escapeHtml(restartCount)}</p>
            <p><span class="text-content-secondary">RAM:</span> ${this.escapeHtml(agent.ram_usage || "—")} / ${this.escapeHtml(agent.ram_limit || "—")} (${ramPercentLabel})</p>
            <div>
              <div class="w-full h-1.5 bg-bg-base rounded-full overflow-hidden border border-border/50">
                <div class="h-full bg-accent" style="width: ${ramPercentWidth}%"></div>
              </div>
              <p class="mt-1 text-[11px]">Usage: ${ramPercentLabel} of ${this.escapeHtml(agent.ram_limit || "—")}</p>
            </div>
            <p><span class="text-content-secondary">Uptime:</span> ${this.escapeHtml(agent.uptime || "—")}</p>
            <p><span class="text-content-secondary">Last Activity:</span> ${this.escapeHtml(agent.last_activity || "No tasks yet")}</p>
            <p><span class="text-content-secondary">Observability:</span> ${this.escapeHtml(obsBackend)}</p>
            ${obsDetails ? `<p class="text-[11px] text-content-muted">Obs: ${this.escapeHtml(obsDetails)}</p>` : ""}
          </div>

          <div class="mt-4 grid grid-cols-2 gap-2" data-action="click->zerobitch-fleet#consumeClick">
            ${this.actionButton(agentId, "start", "▶️ Start", "bg-green-600/80 hover:bg-green-500")}
            ${this.actionButton(agentId, "stop", "⏹ Stop", "bg-yellow-600/80 hover:bg-yellow-500")}
            ${this.actionButton(agentId, "restart", "🔄 Restart", "bg-orange-600/80 hover:bg-orange-500")}
            ${this.actionButton(agentId, "delete", "🗑 Delete", "bg-red-700/80 hover:bg-red-600")}
          </div>

          ${this.renderSparkline(agent.sparkline_mem || [])}
          <details class="mt-3 rounded-md border border-border p-2" data-action="click->zerobitch-fleet#consumeClick">
            <summary class="text-xs text-content-secondary cursor-pointer">🧠 Prompt template</summary>
            <textarea class="mt-2 w-full rounded-md border border-border bg-bg-base px-2 py-1 text-[11px] text-content min-h-24 resize-y" data-template-editor placeholder="Add a default prompt template...">${this.escapeHtml(templateValue)}</textarea>
            <div class="mt-2 flex items-center justify-between">
              <button type="button" class="px-2 py-1 rounded-md text-[11px] bg-emerald-600/80 hover:bg-emerald-500 text-white" data-agent-id="${agentId}" data-action="click->zerobitch-fleet#saveTemplate click->zerobitch-fleet#consumeClick">Save template</button>
              <span class="text-[10px] text-content-muted" data-template-status>${templateStatus}</span>
            </div>
          </details>
          <button type="button" class="mt-3 inline-flex w-full items-center justify-center rounded-md px-3 py-2 text-sm font-medium bg-bg-base border border-border text-content hover:border-accent/40" data-agent-id="${agentId}" data-agent-name="${this.escapeHtml(agent.name || "Agent")}" data-action="click->zerobitch-fleet#openLogs click->zerobitch-fleet#consumeClick">📜 Logs</button>
          <a href="${agent.detail_path}" class="mt-2 inline-flex w-full items-center justify-center rounded-md px-3 py-2 text-sm font-medium bg-accent hover:opacity-90 text-white" data-action="click->zerobitch-fleet#consumeClick">Send Task</a>
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
    if (status === "stopped") return "bg-red-500/15 text-red-400 border-red-500/30"
    if (status === "paused") return "bg-amber-500/15 text-amber-300 border-amber-500/30"
    if (status === "restarting") return "bg-yellow-500/15 text-yellow-300 border-yellow-500/30"
    if (status === "dead") return "bg-rose-500/15 text-rose-300 border-rose-500/30"
    return "bg-slate-500/15 text-slate-300 border-slate-500/30"
  }

  onTemplateInput(event) {
    const textarea = event.target
    if (!textarea?.matches?.("textarea[data-template-editor]")) return
    const card = textarea.closest("[data-agent-id]")
    const agentId = card?.dataset?.agentId
    if (!agentId) return

    this.dirtyTemplates.set(agentId, textarea.value)
    const status = card.querySelector("[data-template-status]")
    if (status) status.textContent = "Unsaved"
  }

  isTemplateFocused() {
    const active = document.activeElement
    if (!active || !active.matches) return false
    return active.matches("textarea[data-template-editor]") && this.gridTarget.contains(active)
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
