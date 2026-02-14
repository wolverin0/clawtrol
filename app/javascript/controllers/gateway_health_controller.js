import { Controller } from "@hotwired/stimulus"

// Polls /api/v1/gateway/health every 30s and shows a status dot
export default class extends Controller {
  static targets = ["dot", "label", "sessions"]
  static values = { interval: { type: Number, default: 30000 } }

  connect() {
    this.poll()
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch("/api/v1/gateway/health", {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      this.updateUI(data)
    } catch (e) {
      this.updateUI({ status: "unreachable", error: e.message })
    }
  }

  updateUI(data) {
    const status = data.status || "unknown"
    const isUp = status === "ok" || status === "healthy" || status === "running"

    if (this.hasDotTarget) {
      this.dotTarget.className = `w-2 h-2 rounded-full ${isUp ? "bg-emerald-400" : "bg-red-400"}`
      this.dotTarget.title = isUp ? "Gateway connected" : `Gateway: ${status}`
    }
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = isUp ? "Online" : "Offline"
      this.labelTarget.className = `text-xs ${isUp ? "text-emerald-400" : "text-red-400"}`
    }
    if (this.hasSessionsTarget && data.activeSessions !== undefined) {
      this.sessionsTarget.textContent = `${data.activeSessions} sessions`
    }
  }
}
