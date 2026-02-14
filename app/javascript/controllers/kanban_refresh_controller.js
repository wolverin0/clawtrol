import { Controller } from "@hotwired/stimulus"
import { subscribeToKanban } from "channels"

/**
 * Auto-refresh controller for kanban board
 * Uses WebSocket for real-time updates with polling as fallback
 * Polling is disabled when WebSocket is connected to reduce server load
 */
export default class extends Controller {
  static values = {
    boardId: Number,
    boardIds: Array,
    interval: { type: Number, default: 15000 },
    apiPath: String
  }

  static targets = ["indicator", "realtimeBadge"]

  connect() {
    this.lastFingerprint = null
    this.isRefreshing = false
    this.isPaused = false
    this.wsConnectedCount = 0
    this.subscriptions = []

    this.fetchFingerprint().then((fp) => {
      this.lastFingerprint = fp
    })

    this.connectWebSocket()
    this.updateRealtimeBadge()

    // Only start polling if WebSocket is not connected
    if (!this.isWebSocketActive()) {
      this.startPolling()
    }

    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)

    this.handleTurboLoad = this.handleTurboLoad.bind(this)
    document.addEventListener("turbo:load", this.handleTurboLoad)
  }

  disconnect() {
    this.stopPolling()
    this.disconnectWebSocket()
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    document.removeEventListener("turbo:load", this.handleTurboLoad)
  }

  isWebSocketActive() {
    return this.wsConnectedCount > 0
  }

  _kanbanBoardIds() {
    const idsRaw = Array.isArray(this.boardIdsValue) ? this.boardIdsValue : []
    const ids = [...new Set(idsRaw.map((x) => Number(x)).filter((x) => Number.isFinite(x) && x > 0))]
    if (ids.length > 0) return ids
    if (this.boardIdValue) return [this.boardIdValue]
    return []
  }

  connectWebSocket() {
    const ids = this._kanbanBoardIds()
    if (ids.length === 0) return

    try {
      this.disconnectWebSocket()

      ids.forEach((boardId) => {
        const sub = subscribeToKanban(boardId, {
          onConnected: () => {
            this.wsConnectedCount += 1
            this.stopPolling()
            this.updateRealtimeBadge()
          },
          onDisconnected: () => {
            this.wsConnectedCount = Math.max(0, this.wsConnectedCount - 1)
            if (this.wsConnectedCount === 0) {
              this.startPolling()
              this.updateRealtimeBadge()
            }
          },
          onReceived: (data) => {
            if (data.type === "refresh" || data.type === "create" || data.type === "update" || data.type === "destroy") {
              this.playStatusSound(data)
              this.refresh()
            }
          }
        })
        this.subscriptions.push(sub)
      })
    } catch (error) {
      console.warn("[KanbanRefresh] WebSocket connection failed, using polling:", error)
      this.startPolling()
    }
  }

  disconnectWebSocket() {
    if (Array.isArray(this.subscriptions)) {
      this.subscriptions.forEach((s) => {
        try { s?.unsubscribe?.() } catch { /* noop */ }
      })
    }
    this.subscriptions = []
    this.wsConnectedCount = 0
  }

  startPolling() {
    if (this.pollInterval) return
    if (this.isWebSocketActive()) return

    this.pollInterval = setInterval(() => {
      this.checkForChanges()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.isPaused = true
    } else {
      this.isPaused = false
      if (!this.isWebSocketActive()) {
        this.checkForChanges()
      }
    }
  }

  handleTurboLoad() {
    this.fetchFingerprint().then((fp) => {
      this.lastFingerprint = fp
    })
  }

  async checkForChanges() {
    if (this.isPaused || this.isRefreshing) return

    try {
      const fingerprint = await this.fetchFingerprint()
      if (this.lastFingerprint && fingerprint !== this.lastFingerprint) {
        this.refresh()
      }
      this.lastFingerprint = fingerprint
    } catch (error) {
      console.warn("Kanban refresh check failed:", error)
    }
  }

  async fetchFingerprint() {
    const apiPath = this.apiPathValue || "/api/v1/boards/" + this.boardIdValue + "/status"
    const response = await fetch(apiPath, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
    if (!response.ok) throw new Error("HTTP " + response.status)
    const data = await response.json()
    return data.fingerprint
  }

  refresh() {
    if (this.isRefreshing) return
    this.isRefreshing = true
    this.showIndicator()
    Turbo.visit(window.location.href, { action: "replace" })
    setTimeout(() => {
      this.isRefreshing = false
      this.hideIndicator()
      this.fetchFingerprint().then((fp) => { this.lastFingerprint = fp })
    }, 1000)
  }

  showIndicator() {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.remove("opacity-0")
      this.indicatorTarget.classList.add("opacity-100")
    }
  }

  hideIndicator() {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.remove("opacity-100")
      this.indicatorTarget.classList.add("opacity-0")
    }
  }

  updateRealtimeBadge() {
    if (!this.hasRealtimeBadgeTarget) return
    const el = this.realtimeBadgeTarget
    if (this.isWebSocketActive()) {
      el.textContent = "Realtime: OK"
      el.classList.remove("bg-status-warning/20", "text-status-warning")
      el.classList.add("bg-status-success/20", "text-status-success")
      el.title = "WebSocket connected (ActionCable)"
    } else {
      el.textContent = "Realtime: POLLING"
      el.classList.remove("bg-status-success/20", "text-status-success")
      el.classList.add("bg-status-warning/20", "text-status-warning")
      el.title = "WebSocket disconnected — using polling fallback"
    }
  }

  manualRefresh() { this.refresh() }

  playStatusSound(data) {
    if (!data.old_status || !data.new_status) return
    const { old_status, new_status } = data
    let sound = null
    if (new_status === "in_progress" && old_status !== "in_progress") {
      sound = "agent_spawn"
    } else if ((new_status === "in_review" || new_status === "done") && old_status === "in_progress") {
      sound = "agent_complete"
    } else if (new_status === "errored" || (old_status === "in_progress" && new_status === "inbox")) {
      sound = "agent_error"
    }
    if (sound) {
      document.dispatchEvent(new CustomEvent("codec:play", { detail: { sound } }))
    }
  }
}
