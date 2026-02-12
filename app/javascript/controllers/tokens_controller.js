import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "error", "summary", "list", "empty"]

  connect() {
    this.expanded = new Set()
    this.refresh()
    this.timer = setInterval(() => this.refresh(), 15000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    try {
      const res = await fetch("/tokens.json", { headers: { "Accept": "application/json" } })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`)
      this.render(data)
    } catch (e) {
      console.error("tokens refresh error", e)
      this.setOffline(e?.message)
    }
  }

  setOffline(message) {
    this.statusTarget.innerHTML = `
      <span class="inline-flex items-center gap-2 px-2 py-1 rounded-full bg-red-500/10 text-red-400 text-xs font-medium border border-red-500/20">
        <span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>
        OFFLINE
      </span>
    `

    if (message) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  toggle(event) {
    const id = event.currentTarget?.dataset?.sessionId
    if (!id) return

    if (this.expanded.has(id)) this.expanded.delete(id)
    else this.expanded.add(id)

    const details = this.element.querySelector(`[data-session-details='${CSS.escape(id)}']`)
    if (details) details.classList.toggle("hidden")
  }

  copy(event) {
    event.preventDefault()
    event.stopPropagation()

    const el = event.currentTarget
    const id = el?.dataset?.sessionId
    if (!id) return

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(id).catch(() => {})
    }

    el.classList.add("ring", "ring-accent/30")
    window.setTimeout(() => el.classList.remove("ring", "ring-accent/30"), 350)
  }

  render(data) {
    if (data.status !== "online") {
      this.setOffline(data.error || "Offline")
      return
    }

    this.errorTarget.classList.add("hidden")

    this.statusTarget.innerHTML = `
      <span class="inline-flex items-center gap-2 px-2 py-1 rounded-full bg-green-500/10 text-green-400 text-xs font-medium border border-green-500/20">
        <span class="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
        ONLINE
      </span>
    `

    const sessions = Array.isArray(data.sessions) ? data.sessions : []

    this.summaryTarget.innerHTML = `
      <div class="flex justify-between items-center text-sm">
        <span class="text-muted">Sessions</span>
        <span class="font-mono">${sessions.length}</span>
      </div>
      <div class="flex justify-between items-center text-sm">
        <span class="text-muted">Total Tokens</span>
        <span class="font-mono">${this.formatInt(data.totalTokens)}</span>
      </div>
      <div class="pt-2 text-[10px] text-muted/70">Updated: ${this.formatTime(data.generatedAt)}</div>
    `

    if (sessions.length === 0) {
      this.listTarget.innerHTML = ""
      this.emptyTarget.classList.remove("hidden")
      return
    }

    this.emptyTarget.classList.add("hidden")

    sessions.sort((a, b) => (b.totalTokens || 0) - (a.totalTokens || 0))

    this.listTarget.innerHTML = sessions.map(s => this.buildRow(s)).join("")

    // Restore expanded state after rerender
    this.expanded.forEach(id => {
      const details = this.element.querySelector(`[data-session-details='${CSS.escape(id)}']`)
      if (details) details.classList.remove("hidden")
    })
  }

  buildRow(s) {
    const sessionId = s.sessionId || s.id
    const totalTokens = Number(s.totalTokens || 0)
    const ctx = Number(s.contextTokens || 0)

    const pct = ctx > 0 ? Math.min(Math.round((totalTokens / ctx) * 100), 100) : 0
    const color = this.pctColor(pct)

    const badge = this.modelBadge(s.model)
    const updated = this.formatTime(s.updatedAt)

    return `
      <div class="bg-card border border-border rounded-lg hover:border-accent/50 transition-colors">
        <button type="button"
                class="w-full text-left px-4 py-3"
                data-action="click->tokens#toggle"
                data-session-id="${this.escapeAttr(sessionId)}">
          <div class="flex justify-between items-start gap-3">
            <div class="min-w-0">
              <div class="font-medium text-text truncate">${this.escapeHtml(s.key || sessionId)}</div>
              <div class="text-xs text-muted font-mono truncate">${this.escapeHtml(sessionId)}</div>
            </div>
            <div class="flex items-center gap-2 flex-shrink-0">
              <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${badge}">
                ${this.escapeHtml(s.model || "unknown")}
              </span>
              <button type="button"
                      class="px-2 py-1 rounded-md bg-gray-500/10 hover:bg-gray-500/20 text-muted text-[10px] font-semibold"
                      title="Copy session id"
                      data-action="click->tokens#copy"
                      data-session-id="${this.escapeAttr(sessionId)}">
                COPY
              </button>
            </div>
          </div>

          <div class="mt-2 space-y-1">
            <div class="flex justify-between text-xs text-muted">
              <span>Total: <span class="font-mono text-text">${this.formatInt(totalTokens)}</span></span>
              <span class="font-mono">${pct}% ctx</span>
            </div>
            <div class="h-1.5 w-full bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full rounded-full ${color}" style="width:${pct}%"></div>
            </div>
          </div>
        </button>

        <div class="hidden px-4 pb-4" data-session-details="${this.escapeAttr(sessionId)}">
          <div class="mt-2 grid grid-cols-2 gap-3 text-xs">
            <div class="bg-gray-500/5 border border-white/5 rounded-md p-2">
              <div class="text-muted">Context Tokens</div>
              <div class="font-mono text-text mt-0.5">${this.formatInt(ctx)}</div>
            </div>
            <div class="bg-gray-500/5 border border-white/5 rounded-md p-2">
              <div class="text-muted">Last Updated</div>
              <div class="font-mono text-text mt-0.5">${this.escapeHtml(updated)}</div>
            </div>
            <div class="bg-gray-500/5 border border-white/5 rounded-md p-2">
              <div class="text-muted">Input / Output</div>
              <div class="font-mono text-text mt-0.5">${this.formatInt(s.inputTokens)} / ${this.formatInt(s.outputTokens)}</div>
            </div>
            <div class="bg-gray-500/5 border border-white/5 rounded-md p-2">
              <div class="text-muted">Kind</div>
              <div class="font-mono text-text mt-0.5">${this.escapeHtml(s.kind || "—")}${s.abortedLastRun ? " · aborted" : ""}</div>
            </div>
          </div>
        </div>
      </div>
    `
  }

  pctColor(pct) {
    if (pct >= 80) return "bg-red-500/80"
    if (pct >= 50) return "bg-yellow-500/80"
    return "bg-green-500/80"
  }

  modelBadge(model) {
    if (!model) return "bg-gray-500/10 text-gray-400 border border-gray-500/20"
    if (model.includes("opus")) return "bg-purple-500/10 text-purple-400 border border-purple-500/20"
    if (model.includes("codex") || model.includes("gpt-4") || model.includes("gpt-5")) return "bg-cyan-500/10 text-cyan-400 border border-cyan-500/20"
    if (model.includes("gemini")) return "bg-green-500/10 text-green-400 border border-green-500/20"
    if (model.includes("glm")) return "bg-amber-500/10 text-amber-400 border border-amber-500/20"
    if (model.includes("sonnet")) return "bg-blue-500/10 text-blue-400 border border-blue-500/20"
    return "bg-gray-500/10 text-gray-400 border border-gray-500/20"
  }

  formatInt(n) {
    try {
      return Number(n || 0).toLocaleString()
    } catch {
      return String(n || 0)
    }
  }

  formatTime(iso) {
    if (!iso) return "—"
    try {
      const d = new Date(iso)
      return d.toLocaleString([], { year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" })
    } catch {
      return String(iso)
    }
  }

  escapeHtml(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }

  escapeAttr(str) {
    return this.escapeHtml(str).replace(/`/g, "&#096;")
  }
}
