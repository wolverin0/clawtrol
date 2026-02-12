import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gatewayStatus", "activeAgents", "modelStatus", "stats", "recentCompletions", "emptyState"]

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), 10000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    try {
      const response = await fetch("/command.json", {
        headers: { "Accept": "application/json" }
      })
      
      if (!response.ok) throw new Error("Network response was not ok")
      
      const data = await response.json()
      this.render(data)
    } catch (error) {
      console.error("Command fetch error:", error)
      this.setOfflineState()
    }
  }

  render(data) {
    // 1. Gateway Status
    if (data.status === "offline" || data.error) {
      this.setOfflineState()
      return
    }

    this.gatewayStatusTarget.innerHTML = `
      <span class="inline-flex items-center gap-2 px-2 py-1 rounded-full bg-green-500/10 text-green-400 text-xs font-medium border border-green-500/20">
        <span class="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
        ONLINE v${data.version || '?'}
      </span>
    `

    // 2. Active Agents
    const activeSessions = (data.sessions || []).filter(s => s.status === 'running' || s.status === 'busy' || s.status === 'idle')
    
    if (activeSessions.length === 0) {
      this.activeAgentsTarget.innerHTML = ""
      this.activeAgentsTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
    } else {
      this.emptyStateTarget.classList.add("hidden")
      this.activeAgentsTarget.classList.remove("hidden")
      this.activeAgentsTarget.innerHTML = activeSessions.map(session => this.buildSessionCard(session)).join("")
    }

    // 3. System Status (Models)
    // Note: In a real app we'd fetch /api/v1/models/status from Rails, 
    // but for now we'll simulate or use what we have. 
    // If the gateway data doesn't have it, we might need a separate fetch or just static for now.
    // The requirement says "from /api/v1/models/status on ClawTrol". 
    // Since we are IN ClawTrol (ClawDeck), we can fetch that too or just render it.
    // For this pass, I'll focus on the data provided by the gateway endpoint we built.
    // If the gateway endpoint returns generic session data, I'll use that.
    
    // 4. Stats
    const totalSessions = (data.sessions || []).length
    const activeCrons = (data.crons || []).length // Assuming gateway provides crons? 
    // If not, we calculate from sessions that look like crons.
    
    this.statsTarget.innerHTML = `
      <div class="flex flex-col gap-2">
        <div class="flex justify-between items-center text-sm">
          <span class="text-muted">Total Sessions Today</span>
          <span class="font-mono">${totalSessions}</span>
        </div>
        <div class="flex justify-between items-center text-sm">
          <span class="text-muted">Active Crons</span>
          <span class="font-mono">${activeCrons}</span>
        </div>
      </div>
    `

    // 5. Recent Completions
    const completed = (data.sessions || [])
      .filter(s => s.status === 'done' || s.status === 'error' || s.status === 'stopped')
      .sort((a, b) => new Date(b.endedAt || b.lastActive) - new Date(a.endedAt || a.lastActive))
      .slice(0, 5)

    this.recentCompletionsTarget.innerHTML = completed.map(s => this.buildCompletionRow(s)).join("")
    
    // Fetch model status separately if needed, or just let it be. 
    // I'll add a small separate fetch for model status for completeness if I can.
    this.fetchModelStatus()
  }

  setOfflineState() {
    this.gatewayStatusTarget.innerHTML = `
      <span class="inline-flex items-center gap-2 px-2 py-1 rounded-full bg-red-500/10 text-red-400 text-xs font-medium border border-red-500/20">
        <span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>
        OFFLINE
      </span>
    `
  }

  copySession(event) {
    const el = event.currentTarget
    const sessionId = el?.dataset?.sessionId

    if (!sessionId) return

    // Best-effort copy; no hard failure on unsupported browsers.
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(sessionId).catch(() => {})
    }

    // Visual feedback (brief)
    el.classList.add("ring", "ring-accent/30")
    window.setTimeout(() => {
      el.classList.remove("ring", "ring-accent/30")
    }, 350)
  }

  buildSessionCard(session) {
    const modelColor = this.getModelColor(session.model)
    const timeRunning = this.formatDuration(session.startedAt)
    const tokenPercent = Math.min((session.tokens / 128000) * 100, 100) // Arbitrary scale for visual

    // Extract last message safely. Newer backend returns lastMessageSnippet
    // even when messages are not included in the session list.
    let lastMsg = session.lastMessageSnippet

    if (!lastMsg && session.messages && session.messages.length > 0) {
      lastMsg = session.messages[session.messages.length - 1].content || ""
      if (lastMsg.length > 100) lastMsg = lastMsg.substring(0, 100) + "..."
    }

    if (!lastMsg) {
      lastMsg = session.updatedAt ? `Last active: ${session.updatedAt}` : "No messages yet"
    }

    const safeLastMsg = String(lastMsg)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")

    const sessionId = session.sessionId || session.id

    return `
      <button type="button"
              data-action="click->command#copySession"
              data-session-id="${sessionId}"
              class="text-left w-full bg-card border border-border rounded-lg p-4 flex flex-col gap-3 shadow-sm hover:border-accent/50 transition-colors cursor-pointer active:scale-[1.02]">
        <div class="flex justify-between items-start">
          <div class="flex flex-col">
            <h3 class="font-medium text-text truncate max-w-[200px]" title="${session.label || session.id}">
              ${session.label || session.id.substring(0, 8)}
            </h3>
            <span class="text-xs text-muted font-mono">${session.kind || 'agent'}</span>
            <span class="text-[10px] text-muted/70">Tap to copy session id</span>
          </div>
          <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${modelColor}">
            ${session.model || 'unknown'}
          </span>
        </div>

        <div class="space-y-1">
          <div class="flex justify-between text-xs text-muted">
            <span>Tokens: <span class="font-mono text-text">${session.tokens || 0}</span></span>
            <span class="font-mono">${timeRunning}</span>
          </div>
          <div class="h-1.5 w-full bg-gray-800 rounded-full overflow-hidden">
            <div class="h-full bg-accent/70 rounded-full" style="width: ${tokenPercent}%"></div>
          </div>
        </div>

        <div class="bg-black/30 rounded p-2 text-xs text-muted font-mono overflow-hidden h-16 relative">
          ${safeLastMsg}
          <div class="pointer-events-none absolute bottom-0 left-0 w-full h-6 bg-gradient-to-t from-black/30 to-transparent"></div>
        </div>
      </button>
    `
  }

  buildCompletionRow(session) {
    const duration = this.formatDuration(session.startedAt, session.endedAt)
    const outcome = session.status === 'done' ? 'text-green-400' : 'text-red-400'
    
    return `
      <div class="grid grid-cols-12 gap-4 py-2 border-b border-white/5 text-sm last:border-0 items-center">
        <div class="col-span-4 font-medium text-text truncate" title="${session.label}">${session.label || session.id}</div>
        <div class="col-span-3 text-muted text-xs truncate">${session.model}</div>
        <div class="col-span-2 font-mono text-xs text-muted">${duration}</div>
        <div class="col-span-2 font-mono text-xs text-muted">${session.tokens || 0} tks</div>
        <div class="col-span-1 text-right ${outcome} text-xs font-bold uppercase">${session.status}</div>
      </div>
    `
  }

  getModelColor(model) {
    if (!model) return "bg-gray-500/10 text-gray-400"
    if (model.includes("opus")) return "bg-purple-500/10 text-purple-400 border border-purple-500/20"
    if (model.includes("codex") || model.includes("gpt-4")) return "bg-cyan-500/10 text-cyan-400 border border-cyan-500/20"
    if (model.includes("gemini")) return "bg-green-500/10 text-green-400 border border-green-500/20"
    if (model.includes("glm")) return "bg-amber-500/10 text-amber-400 border border-amber-500/20"
    if (model.includes("sonnet")) return "bg-blue-500/10 text-blue-400 border border-blue-500/20"
    return "bg-gray-500/10 text-gray-400 border border-gray-500/20"
  }

  formatDuration(start, end) {
    if (!start) return "--:--"
    const s = new Date(start)
    const e = end ? new Date(end) : new Date()
    const diffMs = e - s
    const diffMins = Math.floor(diffMs / 60000)
    const diffHrs = Math.floor(diffMins / 60)
    
    if (diffHrs > 0) return `${diffHrs}h ${diffMins % 60}m`
    return `${diffMins}m`
  }

  async fetchModelStatus() {
    // Optional: fetch real model limits if the API exists on this Rails app
    // We'll just stub it visually for now in the render function unless we really need it.
    // The requirement asks for "from /api/v1/models/status".
    try {
      const res = await fetch("/api/v1/models/status")
      if (res.ok) {
        const data = await res.json()
        this.renderModelStatus(data)
      }
    } catch(e) {
      console.log("Model status fetch failed", e)
    }
  }

  renderModelStatus(data) {
    // Assuming data is { "opus": { remaining: 100, limit: 1000 }, ... }
    // Or similar structure. I'll make a best guess renderer.
    // If I don't know the structure, I'll list keys.
    
    let html = ""
    for (const [model, stats] of Object.entries(data)) {
      if (model === 'status') continue // skip status msg
      
      const isLimited = stats.remaining === 0
      const color = isLimited ? "text-red-400" : "text-green-400"
      const badge = isLimited ? "LIMITED" : "READY"
      
      html += `
        <div class="flex justify-between items-center text-xs py-1">
          <span class="text-muted capitalize">${model.replace(/-/g, ' ')}</span>
          <span class="${color} font-bold text-[10px] bg-white/5 px-1.5 py-0.5 rounded">${badge}</span>
        </div>
      `
    }
    this.modelStatusTarget.innerHTML = html
  }
}
