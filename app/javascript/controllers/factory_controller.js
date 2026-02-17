import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    loops: String,
    modelOptions: String,
    iconPresets: String,
    intervalPresets: String
  }

  static targets = [
    "loopList", "statusMsg", "statusCounts",
    "searchInput", "filterBtn", "sortSelect",
    "detailPanel", "panelBackdrop", "panelIcon", "panelName", "panelSlug", "panelBadge",
    "tabBar", "tabBtn", "tabSettings", "tabLogs", "tabMetrics", "tabAgents", "tabFindings",
    "propName", "propSlug", "propWorkspacePath", "propDesc", "propIconCustom", "iconPicker",
    "propModel", "propFallback", "intervalPicker", "intervalDisplay",
    "propPrompt", "propConfig",
    "saveBtn", "revertBtn",
    "logsList", "metricCycles", "metricErrors", "metricAvg", "metricDetails", "agentsList", "findingsList",
    "createModal", "createName", "createDesc", "createModel", "createInterval", "createIconBtn",
    "createWorkspacePath", "createGithubUrl", "createWorkBranch", "localPathField", "githubField", "sourceTypeBtn",
    "deleteModal", "deleteLoopName"
  ]

  connect() {
    this.loops = []
    this.selectedId = null
    this.filter = "all"
    this.search = ""
    this.sort = "name"
    this.dirty = false
    this.activeTab = "settings"
    this.createIcon = "🏭"
    this.sourceType = "local"
    this._snapshot = null
    this._agentsLoadedFor = null
    this._findingsLoadedFor = null

    try { this.loops = JSON.parse(this.loopsValue || "[]") } catch { this.loops = [] }

    this.renderList()
    this.updateStatusCounts()
    this.updateFilterButtons()

    this.refreshTimer = setInterval(() => this.refreshMetrics(), 15000)
  }

  disconnect() {
    if (this.refreshTimer) clearInterval(this.refreshTimer)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") || ""
  }

  // ── List Rendering ──

  renderList() {
    if (!this.hasLoopListTarget) return

    let filtered = this.loops
    if (this.filter !== "all") filtered = filtered.filter(l => l.status === this.filter)
    if (this.search) {
      const q = this.search.toLowerCase()
      filtered = filtered.filter(l => (l.name || "").toLowerCase().includes(q) || (l.slug || "").toLowerCase().includes(q))
    }

    filtered = this.sortLoops(filtered)

    if (filtered.length === 0) {
      this.loopListTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center py-16 text-content-muted">
          <span class="text-4xl mb-3">🏭</span>
          <p class="text-sm">${this.loops.length === 0 ? "No loops yet. Create one to get started." : "No loops match your filters."}</p>
        </div>`
      return
    }

    this.loopListTarget.innerHTML = filtered.map(loop => this.renderLoopRow(loop)).join("")
  }

  renderLoopRow(loop) {
    const selected = loop.id === this.selectedId
    const intervalText = this.humanInterval(loop.interval_ms)
    const avgText = loop.avg_cycle_duration_ms ? `${(loop.avg_cycle_duration_ms / 1000).toFixed(1)}s` : "—"

    // Sparkline dots
    const dots = (loop.recent_logs || []).map(log => {
      const c = log.status === "completed" ? "bg-green-400" : (log.status === "failed" || log.status === "error") ? "bg-red-400" : "bg-gray-500"
      return `<span class="inline-block w-1.5 h-1.5 rounded-full ${c}" title="${this.esc(log.status)}"></span>`
    }).join("")

    const idlePolicy = loop.idle_policy || "pause"
    const lastCommitSha = loop.last_commit?.sha ? String(loop.last_commit.sha).slice(0, 7) : null
    const lastCommitMsg = loop.last_commit?.message || ""
    const isPlaying = loop.status === "playing"
    const playPauseBtn = isPlaying
      ? `<button data-action="click->factory#quickPause" data-loop-id="${loop.id}" title="Pause" class="w-7 h-7 flex items-center justify-center rounded-md text-amber-400 hover:bg-amber-500/10 transition-colors opacity-0 group-hover:opacity-100">⏸</button>`
      : `<button data-action="click->factory#quickPlay" data-loop-id="${loop.id}" title="Play" class="w-7 h-7 flex items-center justify-center rounded-md text-green-400 hover:bg-green-500/10 transition-colors opacity-0 group-hover:opacity-100">▶</button>`

    return `
      <div data-action="click->factory#selectRow" data-loop-id="${loop.id}"
           class="group flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-150
                  ${selected ? "bg-accent/10 border border-accent/30" : "hover:bg-bg-hover border border-transparent"}">
        <!-- Icon -->
        <span class="text-xl flex-shrink-0">${this.esc(loop.icon)}</span>

        <!-- Main info -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-content truncate">${this.esc(loop.name)}</span>
            <span class="text-[10px] px-1.5 py-0.5 rounded-full font-semibold uppercase tracking-wide flex-shrink-0 ${this.statusBadgeClass(loop.status)}">${loop.status}</span>
          </div>
          <div class="flex items-center gap-2 mt-0.5 flex-wrap">
            <span class="text-[11px] text-content-muted">${this.esc(loop.model || "—")}</span>
            <span class="text-[11px] text-content-muted">⏱ ${intervalText}</span>
            <span class="text-[11px] text-content-muted">🔄 ${loop.total_cycles || 0} cycles</span>
            <span class="text-[11px] text-content-muted">avg ${avgText}</span>
            <span class="text-[10px] px-1.5 py-0.5 rounded-full bg-bg-elevated border border-border text-content-muted">${this.esc(idlePolicy)}</span>
          </div>
          ${lastCommitSha ? `<div class="mt-0.5 text-[10px] text-content-muted truncate">🧾 ${this.esc(lastCommitSha)} ${this.esc(lastCommitMsg)}</div>` : ""}
        </div>

        <!-- Sparkline dots -->
        ${dots ? `<div class="flex gap-0.5 items-center flex-shrink-0">${dots}</div>` : ""}

        <!-- Quick action -->
        ${playPauseBtn}

        <!-- Kebab -->
        <button data-action="click->factory#openKebab" data-loop-id="${loop.id}" title="More"
                class="w-7 h-7 flex items-center justify-center rounded-md text-content-muted hover:text-content hover:bg-bg-hover transition-colors opacity-0 group-hover:opacity-100">⋮</button>
      </div>`
  }

  sortLoops(loops) {
    const arr = [...loops]
    switch (this.sort) {
      case "name": return arr.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
      case "last_run": return arr.sort((a, b) => {
        const at = a.last_cycle_at || ""; const bt = b.last_cycle_at || ""
        return bt.localeCompare(at)
      })
      case "interval": return arr.sort((a, b) => (a.interval_ms || 0) - (b.interval_ms || 0))
      case "status": {
        const order = { playing: 0, paused: 1, error: 2, stopped: 3, idle: 4 }
        return arr.sort((a, b) => (order[a.status] ?? 9) - (order[b.status] ?? 9))
      }
      default: return arr
    }
  }

  statusBadgeClass(status) {
    switch (status) {
      case "playing": return "text-green-300 bg-green-500/15"
      case "paused": return "text-amber-300 bg-amber-500/15"
      case "stopped": return "text-gray-400 bg-gray-500/15"
      case "error": return "text-red-300 bg-red-500/15"
      default: return "text-gray-400 bg-gray-500/15"
    }
  }

  // ── Search / Filter / Sort ──

  onSearch() { this.search = this.searchInputTarget.value; this.renderList() }

  setFilter(event) {
    this.filter = event.currentTarget.dataset.filter
    this.updateFilterButtons()
    this.renderList()
  }

  updateFilterButtons() {
    this.filterBtnTargets.forEach(btn => {
      const active = btn.dataset.filter === this.filter
      btn.classList.toggle("border-accent/50", active)
      btn.classList.toggle("text-accent", active)
      btn.classList.toggle("bg-accent/10", active)
      btn.classList.toggle("border-border", !active)
      btn.classList.toggle("text-content-muted", !active)
      btn.classList.toggle("bg-bg-surface", !active)
    })
  }

  onSort() { this.sort = this.sortSelectTarget.value; this.renderList() }

  // ── Row Selection ──

  selectRow(event) {
    // Don't select if clicking a button inside the row
    if (event.target.closest("button")) return
    const id = parseInt(event.currentTarget.dataset.loopId)
    this.selectLoop(id)
  }

  selectLoop(id) {
    this.selectedId = id
    this.dirty = false
    this._snapshot = null
    this.renderList()
    this.openPanel()
    this.syncPanel()
    this.switchToTab("settings")
  }

  // ── Detail Panel ──

  openPanel() {
    if (!this.hasDetailPanelTarget) return
    this.detailPanelTarget.classList.remove("translate-x-full")
    this.detailPanelTarget.classList.add("translate-x-0")
    if (this.hasPanelBackdropTarget) {
      this.panelBackdropTarget.classList.remove("hidden")
    }
  }

  closePanel() {
    if (!this.hasDetailPanelTarget) return
    this.detailPanelTarget.classList.add("translate-x-full")
    this.detailPanelTarget.classList.remove("translate-x-0")
    if (this.hasPanelBackdropTarget) {
      this.panelBackdropTarget.classList.add("hidden")
    }
    this.selectedId = null
    this.dirty = false
    this.renderList()
  }

  syncPanel() {
    const loop = this.loops.find(l => l.id === this.selectedId)
    if (!loop) return

    // Header
    if (this.hasPanelIconTarget) this.panelIconTarget.textContent = loop.icon
    if (this.hasPanelNameTarget) this.panelNameTarget.textContent = loop.name
    if (this.hasPanelSlugTarget) this.panelSlugTarget.textContent = loop.slug || "—"
    if (this.hasPropWorkspacePathTarget) this.propWorkspacePathTarget.textContent = loop.workspace_path || "—"
    if (this.hasPanelBadgeTarget) {
      this.panelBadgeTarget.textContent = loop.status
      this.panelBadgeTarget.className = `ml-2 text-[10px] px-2 py-0.5 rounded-full font-semibold uppercase tracking-wide ${this.statusBadgeClass(loop.status)}`
    }

    // Settings fields
    if (this.hasPropNameTarget) this.propNameTarget.value = loop.name || ""
    if (this.hasPropSlugTarget) this.propSlugTarget.textContent = loop.slug || "—"
    if (this.hasPropDescTarget) this.propDescTarget.value = loop.description || ""
    if (this.hasPropIconCustomTarget) this.propIconCustomTarget.value = loop.icon || ""
    if (this.hasPropModelTarget) this.propModelTarget.value = loop.model || "opus"
    if (this.hasPropFallbackTarget) this.propFallbackTarget.value = loop.fallback_model || ""
    if (this.hasPropPromptTarget) this.propPromptTarget.value = loop.system_prompt || ""

    if (this.hasPropConfigTarget) {
      try {
        const cfg = typeof loop.config === "string" ? JSON.parse(loop.config) : (loop.config || {})
        this.propConfigTarget.value = Object.keys(cfg).length ? JSON.stringify(cfg, null, 2) : ""
      } catch { this.propConfigTarget.value = "" }
    }

    // Icon picker highlight
    if (this.hasIconPickerTarget) {
      this.iconPickerTarget.querySelectorAll("button").forEach(btn => {
        btn.classList.toggle("border-accent", btn.dataset.icon === loop.icon)
        btn.classList.toggle("bg-accent/10", btn.dataset.icon === loop.icon)
      })
    }

    // Interval picker
    if (this.hasIntervalPickerTarget) {
      this.intervalPickerTarget.querySelectorAll("button").forEach(btn => {
        const active = parseInt(btn.dataset.ms) === loop.interval_ms
        btn.classList.toggle("border-accent", active)
        btn.classList.toggle("text-accent", active)
        btn.classList.toggle("bg-accent/10", active)
      })
    }
    if (this.hasIntervalDisplayTarget) {
      this.intervalDisplayTarget.textContent = `${this.humanInterval(loop.interval_ms)} (${(loop.interval_ms || 0).toLocaleString()}ms)`
    }

    // Metrics
    if (this.hasMetricCyclesTarget) this.metricCyclesTarget.textContent = loop.total_cycles || 0
    if (this.hasMetricErrorsTarget) this.metricErrorsTarget.textContent = loop.total_errors || 0
    if (this.hasMetricAvgTarget) this.metricAvgTarget.textContent = loop.avg_cycle_duration_ms ? `${(loop.avg_cycle_duration_ms / 1000).toFixed(1)}s` : "—"

    // Logs
    this.renderLogs(loop)

    // Save snapshot for revert
    this._snapshot = this.captureSnapshot(loop)
    this.setDirty(false)
  }

  // ── Tabs ──

  switchTab(event) {
    this.switchToTab(event.currentTarget.dataset.tab)
  }

  switchToTab(tab) {
    this.activeTab = tab
    this.tabBtnTargets.forEach(btn => {
      const active = btn.dataset.tab === tab
      btn.classList.toggle("border-accent", active)
      btn.classList.toggle("text-accent", active)
      btn.classList.toggle("border-transparent", !active)
      btn.classList.toggle("text-content-muted", !active)
    })
    if (this.hasTabSettingsTarget) this.tabSettingsTarget.classList.toggle("hidden", tab !== "settings")
    if (this.hasTabLogsTarget) this.tabLogsTarget.classList.toggle("hidden", tab !== "logs")
    if (this.hasTabMetricsTarget) this.tabMetricsTarget.classList.toggle("hidden", tab !== "metrics")
    if (this.hasTabAgentsTarget) this.tabAgentsTarget.classList.toggle("hidden", tab !== "agents")
    if (this.hasTabFindingsTarget) this.tabFindingsTarget.classList.toggle("hidden", tab !== "findings")

    if (tab === "agents") this.loadAgents()
    if (tab === "findings") this.loadFindings()
  }

  // ── Logs ──

  renderLogs(loop) {
    if (!this.hasLogsListTarget) return
    const logs = (loop.recent_logs || []).slice().reverse()
    if (logs.length === 0) {
      this.logsListTarget.innerHTML = '<p class="text-xs text-content-muted py-4 text-center">No cycle logs yet.</p>'
      return
    }
    this.logsListTarget.innerHTML = logs.map(log => {
      const color = log.status === "completed" ? "border-green-500/30 bg-green-500/5" :
                    (log.status === "failed" || log.status === "error") ? "border-red-500/30 bg-red-500/5" : "border-border bg-bg-elevated"
      const dot = log.status === "completed" ? "bg-green-400" :
                  (log.status === "failed" || log.status === "error") ? "bg-red-400" : "bg-gray-500"
      const time = log.started_at ? new Date(log.started_at).toLocaleString() : ""
      return `
        <div class="border rounded-md p-3 ${color}">
          <div class="flex items-center gap-2">
            <span class="w-2 h-2 rounded-full ${dot} flex-shrink-0"></span>
            <span class="text-[11px] font-medium text-content uppercase">${this.esc(log.status)}</span>
            <span class="text-[10px] text-content-muted ml-auto">${time}</span>
          </div>
          ${log.summary ? `<p class="text-[11px] text-content-muted mt-1 line-clamp-2">${this.esc(log.summary)}</p>` : ""}
        </div>`
    }).join("")
  }

  async loadAgents(force = false) {
    if (!this.selectedId || !this.hasAgentsListTarget) return
    if (!force && this._agentsLoadedFor === this.selectedId) return

    this.agentsListTarget.innerHTML = '<p class="text-xs text-content-muted">Loading agents…</p>'
    try {
      const res = await fetch(`/api/v1/factory/loops/${this.selectedId}/agents`, {
        headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken }
      })
      if (!res.ok) throw new Error("failed")
      const data = await res.json()
      this.renderAgents(data || [])
      this._agentsLoadedFor = this.selectedId
    } catch {
      this.agentsListTarget.innerHTML = '<p class="text-xs text-red-400">Failed to load agents.</p>'
    }
  }

  renderAgents(agents) {
    if (!this.hasAgentsListTarget) return
    if (!agents.length) {
      this.agentsListTarget.innerHTML = '<p class="text-xs text-content-muted py-4 text-center">No agents assigned to this loop.</p>'
      return
    }

    this.agentsListTarget.innerHTML = agents.map(agent => {
      const enabled = !!agent.enabled
      const ready = !agent.on_cooldown
      const lastRun = agent.last_run_at ? new Date(agent.last_run_at).toLocaleString() : "Never"
      const cooldownUntil = agent.cooldown_until ? new Date(agent.cooldown_until).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : null
      return `
        <div class="border border-border rounded-md p-3 bg-bg-elevated">
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <div class="text-sm text-content font-medium truncate">${this.esc(agent.name)}</div>
              <div class="mt-1 flex items-center gap-2 text-[11px] text-content-muted">
                <span class="px-1.5 py-0.5 rounded-full border border-border bg-bg-surface">${this.esc(agent.category || "general")}</span>
                <span>Last run: ${this.esc(lastRun)}</span>
              </div>
              <div class="mt-1 text-[11px] ${ready ? "text-green-300" : "text-amber-300"}">
                ${ready ? "Ready" : `On cooldown until ${this.esc(cooldownUntil || "—")}`}
              </div>
            </div>
            <button type="button" data-action="factory#toggleAgent" data-agent-id="${agent.id}" data-enabled="${enabled ? "true" : "false"}"
                    class="px-2.5 py-1 text-[11px] rounded-md border ${enabled ? "text-red-300 border-red-500/30 bg-red-500/10" : "text-green-300 border-green-500/30 bg-green-500/10"}">
              ${enabled ? "Disable" : "Enable"}
            </button>
          </div>
        </div>`
    }).join("")
  }

  async toggleAgent(event) {
    event.preventDefault()
    const agentId = event.currentTarget.dataset.agentId
    const enabled = event.currentTarget.dataset.enabled === "true"
    const action = enabled ? "disable" : "enable"

    try {
      const res = await fetch(`/api/v1/factory/loops/${this.selectedId}/agents/${agentId}/${action}`, {
        method: "POST",
        headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken }
      })
      if (!res.ok) throw new Error("failed")
      await this.loadAgents(true)
      this.setStatus(`Agent ${enabled ? "disabled" : "enabled"}`)
    } catch {
      this.setStatus("⚠ Failed to update agent")
    }
  }

  async loadFindings(force = false) {
    if (!this.selectedId || !this.hasFindingsListTarget) return
    if (!force && this._findingsLoadedFor === this.selectedId) return

    this.findingsListTarget.innerHTML = '<p class="text-xs text-content-muted">Loading findings…</p>'
    try {
      const res = await fetch(`/api/v1/factory/loops/${this.selectedId}/findings`, {
        headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken }
      })
      if (!res.ok) throw new Error("failed")
      const data = await res.json()
      this.renderFindings(data || [])
      this._findingsLoadedFor = this.selectedId
    } catch {
      this.findingsListTarget.innerHTML = '<p class="text-xs text-red-400">Failed to load findings.</p>'
    }
  }

  renderFindings(runs) {
    if (!this.hasFindingsListTarget) return
    if (!runs.length) {
      this.findingsListTarget.innerHTML = '<p class="text-xs text-content-muted py-4 text-center">No findings for this loop yet.</p>'
      return
    }

    this.findingsListTarget.innerHTML = runs.map(run => {
      const agentName = run.factory_agent?.name || "Unknown Agent"
      const runAt = run.created_at ? new Date(run.created_at).toLocaleString() : "—"
      const sha = run.commit_sha ? String(run.commit_sha).slice(0, 7) : "—"
      const findings = Array.isArray(run.findings) ? run.findings : []

      const findingsHtml = findings.length ? findings.map(f => {
        const confidence = Number(f.confidence || f.score || 0)
        const confidenceClass = confidence > 80 ? "text-green-300" : (confidence >= 50 ? "text-amber-300" : "text-red-300")
        const description = f.description || f.summary || "No description"
        return `
          <div class="border border-border rounded-md p-2 bg-bg-surface">
            <div class="text-[12px] text-content">${this.esc(description)}</div>
            <div class="mt-1 flex items-center justify-between gap-2">
              <span class="text-[11px] ${confidenceClass}">Confidence: ${Number.isFinite(confidence) ? confidence : 0}%</span>
              <div class="flex items-center gap-1">
                <button type="button" class="px-2 py-0.5 text-[10px] rounded border border-green-500/30 text-green-300 bg-green-500/10">Accept</button>
                <button type="button" class="px-2 py-0.5 text-[10px] rounded border border-red-500/30 text-red-300 bg-red-500/10">Dismiss</button>
              </div>
            </div>
          </div>`
      }).join("") : '<p class="text-[11px] text-content-muted">No findings payload.</p>'

      return `
        <div class="border border-border rounded-md p-3 bg-bg-elevated space-y-2">
          <div class="text-[11px] text-content-muted">${this.esc(agentName)} · ${this.esc(runAt)} · commit ${this.esc(sha)}</div>
          ${findingsHtml}
        </div>`
    }).join("")
  }

  // ── Dirty tracking ──

  captureSnapshot(loop) {
    return {
      name: loop.name || "", description: loop.description || "", icon: loop.icon || "",
      model: loop.model || "", fallback_model: loop.fallback_model || "",
      interval_ms: loop.interval_ms, system_prompt: loop.system_prompt || "",
      config: JSON.stringify(typeof loop.config === "object" ? loop.config : {})
    }
  }

  markDirty() {
    this.setDirty(true)
  }

  setDirty(val) {
    this.dirty = val
    if (this.hasSaveBtnTarget) this.saveBtnTarget.disabled = !val
    if (this.hasRevertBtnTarget) this.revertBtnTarget.disabled = !val
  }

  pickIcon(event) {
    event.preventDefault()
    const icon = event.currentTarget.dataset.icon
    if (this.hasPropIconCustomTarget) this.propIconCustomTarget.value = icon
    if (this.hasIconPickerTarget) {
      this.iconPickerTarget.querySelectorAll("button").forEach(btn => {
        btn.classList.toggle("border-accent", btn.dataset.icon === icon)
        btn.classList.toggle("bg-accent/10", btn.dataset.icon === icon)
      })
    }
    this.setDirty(true)
  }

  pickInterval(event) {
    event.preventDefault()
    const ms = parseInt(event.currentTarget.dataset.ms)
    if (this.hasIntervalPickerTarget) {
      this.intervalPickerTarget.querySelectorAll("button").forEach(btn => {
        const active = parseInt(btn.dataset.ms) === ms
        btn.classList.toggle("border-accent", active)
        btn.classList.toggle("text-accent", active)
        btn.classList.toggle("bg-accent/10", active)
      })
    }
    if (this.hasIntervalDisplayTarget) {
      this.intervalDisplayTarget.textContent = `${this.humanInterval(ms)} (${ms.toLocaleString()}ms)`
    }
    // Store on a temp var, applied on save
    this._pendingInterval = ms
    this.setDirty(true)
  }

  // ── Save / Revert ──

  async saveLoop() {
    const loop = this.loops.find(l => l.id === this.selectedId)
    if (!loop) return

    // Read values from form
    loop.name = this.hasPropNameTarget ? this.propNameTarget.value : loop.name
    loop.description = this.hasPropDescTarget ? this.propDescTarget.value : loop.description
    loop.icon = this.hasPropIconCustomTarget ? (this.propIconCustomTarget.value || loop.icon) : loop.icon
    loop.model = this.hasPropModelTarget ? this.propModelTarget.value : loop.model
    loop.fallback_model = this.hasPropFallbackTarget ? this.propFallbackTarget.value : loop.fallback_model
    loop.system_prompt = this.hasPropPromptTarget ? this.propPromptTarget.value : loop.system_prompt
    if (this._pendingInterval) { loop.interval_ms = this._pendingInterval; this._pendingInterval = null }

    try {
      const raw = this.hasPropConfigTarget ? this.propConfigTarget.value.trim() : ""
      loop.config = raw ? JSON.parse(raw) : {}
    } catch { /* keep existing */ }

    loop.slug = loop.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")

    let configVal = loop.config
    if (typeof configVal === "string") { try { configVal = JSON.parse(configVal) } catch { configVal = {} } }

    const res = await fetch(`/factory/loops/${loop.id}`, {
      method: "PATCH",
      headers: { "X-CSRF-Token": this.csrfToken, "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({
        factory_loop: {
          name: loop.name, slug: loop.slug, description: loop.description, icon: loop.icon,
          model: loop.model, fallback_model: loop.fallback_model, interval_ms: loop.interval_ms,
          system_prompt: loop.system_prompt, config: configVal
        }
      })
    })

    if (res.ok) {
      this._snapshot = this.captureSnapshot(loop)
      this.setDirty(false)
      this.syncPanel()
      this.renderList()
      this.updateStatusCounts()
      this.setStatus("✓ Saved")
    } else {
      const data = await res.json().catch(() => ({}))
      this.setStatus(`⚠ Save failed: ${data.error || res.statusText}`)
    }
  }

  revertLoop() {
    const loop = this.loops.find(l => l.id === this.selectedId)
    if (!loop || !this._snapshot) return

    Object.assign(loop, {
      name: this._snapshot.name, description: this._snapshot.description,
      icon: this._snapshot.icon, model: this._snapshot.model,
      fallback_model: this._snapshot.fallback_model, interval_ms: this._snapshot.interval_ms,
      system_prompt: this._snapshot.system_prompt
    })
    try { loop.config = JSON.parse(this._snapshot.config) } catch { loop.config = {} }

    this._pendingInterval = null
    this.syncPanel()
    this.renderList()
    this.setDirty(false)
  }

  // ── Status Controls ──

  async quickPlay(event) {
    event.stopPropagation()
    const id = parseInt(event.currentTarget.dataset.loopId)
    await this._controlAction(id, "play")
  }

  async quickPause(event) {
    event.stopPropagation()
    const id = parseInt(event.currentTarget.dataset.loopId)
    await this._controlAction(id, "pause")
  }

  async playSelected() { if (this.selectedId) await this._controlAction(this.selectedId, "play") }
  async pauseSelected() { if (this.selectedId) await this._controlAction(this.selectedId, "pause") }
  async stopSelected() { if (this.selectedId) await this._controlAction(this.selectedId, "stop") }

  async _controlAction(id, action) {
    const loop = this.loops.find(l => l.id === id)
    if (!loop) return

    // Optimistic update
    const prevStatus = loop.status
    const statusMap = { play: "playing", pause: "paused", stop: "stopped" }
    loop.status = statusMap[action] || action
    this.renderList()
    if (loop.id === this.selectedId) this.syncPanel()
    this.updateStatusCounts()

    const res = await fetch(`/factory/${loop.id}/${action}`, {
      method: "POST",
      headers: { "X-CSRF-Token": this.csrfToken, "Accept": "application/json" }
    })

    if (res.ok) {
      const data = await res.json().catch(() => ({}))
      loop.status = data.status || loop.status
      this.setStatus(`${loop.name}: ${loop.status}`)
    } else {
      loop.status = prevStatus // Rollback
      this.setStatus(`⚠ ${action} failed`)
    }
    this.renderList()
    if (loop.id === this.selectedId) this.syncPanel()
    this.updateStatusCounts()
  }

  // ── Kebab Menu ──

  openKebab(event) {
    event.stopPropagation()
    const id = parseInt(event.currentTarget.dataset.loopId)
    this.selectedId = id
    this.deleteSelected()
  }

  // ── Create Loop ──

  openCreateModal() {
    if (!this.hasCreateModalTarget) return
    this.createModalTarget.classList.remove("hidden")
    this.createIcon = "🏭"
    this.sourceType = "local"
    if (this.hasCreateNameTarget) this.createNameTarget.value = ""
    if (this.hasCreateDescTarget) this.createDescTarget.value = ""
    if (this.hasCreateWorkspacePathTarget) this.createWorkspacePathTarget.value = ""
    if (this.hasCreateGithubUrlTarget) this.createGithubUrlTarget.value = ""
    if (this.hasCreateWorkBranchTarget) this.createWorkBranchTarget.value = "factory/auto"
    this.createIconBtnTargets.forEach(btn => {
      btn.classList.toggle("border-accent", btn.dataset.icon === "🏭")
      btn.classList.toggle("bg-accent/10", btn.dataset.icon === "🏭")
    })
    this.sourceTypeBtnTargets.forEach(btn => {
      const isActive = btn.dataset.source === "local"
      btn.classList.toggle("border-accent", isActive)
      btn.classList.toggle("bg-accent/10", isActive)
      btn.classList.toggle("text-accent", isActive)
      btn.classList.toggle("border-border", !isActive)
      btn.classList.toggle("text-content-muted", !isActive)
    })
    if (this.hasLocalPathFieldTarget) this.localPathFieldTarget.classList.remove("hidden")
    if (this.hasGithubFieldTarget) this.githubFieldTarget.classList.add("hidden")
    setTimeout(() => { if (this.hasCreateNameTarget) this.createNameTarget.focus() }, 100)
  }

  closeCreateModal() {
    if (this.hasCreateModalTarget) this.createModalTarget.classList.add("hidden")
  }

  pickCreateIcon(event) {
    event.preventDefault()
    this.createIcon = event.currentTarget.dataset.icon
    this.createIconBtnTargets.forEach(btn => {
      btn.classList.toggle("border-accent", btn.dataset.icon === this.createIcon)
      btn.classList.toggle("bg-accent/10", btn.dataset.icon === this.createIcon)
    })
  }

  setSourceType(e) {
    const source = e.currentTarget.dataset.source
    this.sourceType = source
    this.sourceTypeBtnTargets.forEach(btn => {
      const isActive = btn.dataset.source === source
      btn.classList.toggle("border-accent", isActive)
      btn.classList.toggle("bg-accent/10", isActive)
      btn.classList.toggle("text-accent", isActive)
      btn.classList.toggle("border-border", !isActive)
      btn.classList.toggle("text-content-muted", !isActive)
    })
    if (this.hasLocalPathFieldTarget) this.localPathFieldTarget.classList.toggle("hidden", source !== "local")
    if (this.hasGithubFieldTarget) this.githubFieldTarget.classList.toggle("hidden", source !== "github")
  }

  async createLoop() {
    const name = this.hasCreateNameTarget ? this.createNameTarget.value.trim() : ""
    if (!name) { this.setStatus("⚠ Name is required"); return }

    const desc = this.hasCreateDescTarget ? this.createDescTarget.value.trim() : ""
    const model = this.hasCreateModelTarget ? this.createModelTarget.value : "opus"
    const intervalMs = this.hasCreateIntervalTarget ? parseInt(this.createIntervalTarget.value) : 900000
    const workspacePath = this.hasCreateWorkspacePathTarget ? this.createWorkspacePathTarget.value.trim() : ""
    const githubUrl = this.hasCreateGithubUrlTarget ? this.createGithubUrlTarget.value.trim() : ""
    const workBranch = this.hasCreateWorkBranchTarget ? this.createWorkBranchTarget.value.trim() : "factory/auto"

    // If github, workspace_path will be set server-side after clone
    const finalWorkspacePath = this.sourceType === "github" ? "" : workspacePath
    if (!finalWorkspacePath && this.sourceType !== "github") { this.setStatus("⚠ Workspace path required"); return }
    if (!githubUrl && this.sourceType === "github") { this.setStatus("⚠ GitHub URL required"); return }

    const res = await fetch("/factory/loops", {
      method: "POST",
      headers: { "X-CSRF-Token": this.csrfToken, "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({ factory_loop: { name, description: desc, icon: this.createIcon, model, interval_ms: intervalMs, workspace_path: finalWorkspacePath, work_branch: workBranch, config: { github_url: githubUrl || null } } })
    })

    if (res.ok) {
      const data = await res.json().catch(() => ({}))
      if (data.id) {
        this.loops.push(data)
        this.closeCreateModal()
        this.renderList()
        this.updateStatusCounts()
        this.selectLoop(data.id)
        this.setStatus(`✓ Created "${name}"`)
      } else {
        // API returned OK but no id — reload
        window.location.reload()
      }
    } else {
      const data = await res.json().catch(() => ({}))
      this.setStatus(`⚠ ${data.error || "Failed to create"}`)
    }
  }

  // ── Delete ──

  deleteSelected() {
    const loop = this.loops.find(l => l.id === this.selectedId)
    if (!loop) return
    if (this.hasDeleteLoopNameTarget) this.deleteLoopNameTarget.textContent = loop.name
    if (this.hasDeleteModalTarget) this.deleteModalTarget.classList.remove("hidden")
  }

  closeDeleteModal() {
    if (this.hasDeleteModalTarget) this.deleteModalTarget.classList.add("hidden")
  }

  async confirmDelete() {
    const loop = this.loops.find(l => l.id === this.selectedId)
    if (!loop) return

    const res = await fetch(`/factory/loops/${loop.id}`, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken, "Accept": "application/json" }
    })

    if (res.ok || res.redirected) {
      this.loops = this.loops.filter(l => l.id !== loop.id)
      this.closeDeleteModal()
      this.closePanel()
      this.renderList()
      this.updateStatusCounts()
      this.setStatus(`Deleted "${loop.name}"`)
    } else {
      this.setStatus("⚠ Delete failed")
    }
  }

  // ── Metrics Refresh ──

  refreshMetrics() {
    this.loops.forEach(loop => {
      fetch(`/api/v1/factory/loops/${loop.id}/metrics`, { headers: { "Accept": "application/json" } })
        .then(r => r.ok ? r.json() : null)
        .then(data => {
          if (!data) return
          loop.status = data.status || loop.status
          loop.total_cycles = data.total_cycles ?? loop.total_cycles
          loop.total_errors = data.total_errors ?? loop.total_errors
          loop.avg_cycle_duration_ms = data.avg_cycle_duration_ms ?? loop.avg_cycle_duration_ms
          if (loop.id === this.selectedId) this.syncPanel()
        }).catch(() => {})
    })
    this.renderList()
    this.updateStatusCounts()
  }

  updateStatusCounts() {
    if (!this.hasStatusCountsTarget) return
    const playing = this.loops.filter(l => l.status === "playing").length
    const paused = this.loops.filter(l => l.status === "paused").length
    const total = this.loops.length
    this.statusCountsTarget.textContent = `${playing} playing · ${paused} paused · ${total} total`
  }

  // ── Helpers ──

  humanInterval(ms) {
    if (!ms || ms <= 0) return "—"
    const mins = ms / 60000
    if (mins < 60) return `${mins}m`
    const h = Math.floor(mins / 60)
    const m = mins % 60
    return m > 0 ? `${h}h${m}m` : `${h}h`
  }

  setStatus(text) {
    if (!this.hasStatusMsgTarget) return
    this.statusMsgTarget.textContent = text
    clearTimeout(this._statusTimer)
    this._statusTimer = setTimeout(() => { this.statusMsgTarget.textContent = "" }, 4000)
  }

  esc(str) {
    return String(str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }
}
