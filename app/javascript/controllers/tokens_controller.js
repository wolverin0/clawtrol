import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "error", "summary", "list", "empty"]

  connect() {
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

  copy(event) {
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
  }

  buildRow(s) {
    const tokens = Number(s.totalTokens || 0)
    const pct = Math.min(Math.round((tokens / 128000) * 100), 100)
    const badge = this.modelBadge(s.model)

    return `
      <button type="button"
              class="w-full text-left bg-card border border-border rounded-lg px-4 py-3 hover:border-accent/50 transition-colors"
              data-action="click->tokens#copy"
              data-session-id="${this.escapeAttr(s.sessionId || s.id)}">
        <div class="flex justify-between items-start gap-3">
          <div class="min-w-0">
            <div class="font-medium text-text truncate">${this.escapeHtml(s.key || s.sessionId || s.id)}</div>
            <div class="text-xs text-muted font-mono truncate">${this.escapeHtml(s.sessionId || s.id)}</div>
          </div>
          <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${badge}">
            ${this.escapeHtml(s.model || "unknown")}
          </span>
        </div>

        <div class="mt-2 space-y-1">
          <div class="flex justify-between text-xs text-muted">
            <span>Tokens: <span class="font-mono text-text">${this.formatInt(tokens)}</span></span>
            <span class="font-mono">${pct}% ctx</span>
          </div>
          <div class="h-1.5 w-full bg-gray-800 rounded-full overflow-hidden">
            <div class="h-full bg-accent/70 rounded-full" style="width:${pct}%"></div>
          </div>
        </div>
      </button>
    `
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
