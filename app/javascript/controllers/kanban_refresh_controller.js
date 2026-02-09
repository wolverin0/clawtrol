import { Controller } from "@hotwired/stimulus"
import { subscribeToKanban } from "channels"

/**
 * Auto-refresh controller for kanban board
 * Uses WebSocket for real-time updates with polling as fallback
 */
export default class extends Controller {
  static values = {
    boardId: Number,
    boardIds: Array,
    interval: { type: Number, default: 15000 }, // 15 seconds default (fallback polling)
    apiPath: String
  }

  static targets = ["indicator", "realtimeBadge"]

  connect() {
    this.lastFingerprint = null
    this.isRefreshing = false
    this.isPaused = false

    this.wsConnectedCount = 0
    this.subscriptions = []

    // Get initial fingerprint
    this.fetchFingerprint().then((fp) => {
      this.lastFingerprint = fp
    })

    // Try WebSocket first
    this.connectWebSocket()
    this.updateRealtimeBadge()

    // Pause when tab is not visible
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)

    // Listen for Turbo events to reset fingerprint after navigation
    this.handleTurboLoad = this.handleTurboLoad.bind(this)
    document.addEventListener("turbo:load", this.handleTurboLoad)
  }

  disconnect() {
    this.stopPolling()
    this.disconnectWebSocket()
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    document.removeEventListener("turbo:load", this.handleTurboLoad)
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
      // Reset in case connectWebSocket is called more than once.
      this.disconnectWebSocket()

      ids.forEach((boardId) => {
        const sub = subscribeToKanban(boardId, {
          onConnected: () => {
            this.wsConnectedCount += 1
            if (this.wsConnectedCount === 1) {
              this.stopPolling() // Disable polling when WebSocket is active
              this.updateRealtimeBadge()
              console.log("[KanbanRefresh] WebSocket connected, polling disabled")
            }
          },
          onDisconnected: () => {
            this.wsConnectedCount = Math.max(0, this.wsConnectedCount - 1)
            if (this.wsConnectedCount === 0) {
              this.startPolling() // Re-enable polling as fallback
              this.updateRealtimeBadge()
              console.log("[KanbanRefresh] WebSocket disconnected, polling enabled")
            }
          },
          onReceived: (data) => {
            // Trigger refresh when we get a message
            if (data.type === "refresh" || data.type === "create" || data.type === "update" || data.type === "destroy") {
              // Play codec sounds for agent-related status transitions
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
        try {
          s?.unsubscribe?.()
        } catch {
          // noop
        }
      })
    }

    this.subscriptions = []
    this.wsConnectedCount = 0
  }

  startPolling() {
    if (this.pollInterval) return // Already polling

    this.pollInterval = setInterval(() => {
      this.checkForChanges()
    }, this.intervalValue)
    console.log("[KanbanRefresh] Polling started (fallback mode)")
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
      console.log("[KanbanRefresh] Polling stopped")
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.isPaused = true
    } else {
      this.isPaused = false
      // Check immediately when tab becomes visible again
      if (this.wsConnectedCount === 0) {
        this.checkForChanges()
      }
    }
  }

  handleTurboLoad() {
    // Update fingerprint after a Turbo navigation
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
    const apiPath = this.apiPathValue || `/api/v1/boards/${this.boardIdValue}/status`
    const response = await fetch(apiPath, {
      headers: {
        Accept: "application/json"
      },
      credentials: "same-origin"
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`)
    }

    const data = await response.json()
    return data.fingerprint
  }

  refresh() {
    if (this.isRefreshing) return

    this.isRefreshing = true
    this.showIndicator()

    // Use Turbo to refresh the page content
    Turbo.visit(window.location.href, { action: "replace" })

    // Reset state after a short delay
    setTimeout(() => {
      this.isRefreshing = false
      this.hideIndicator()
      // Update fingerprint after refresh
      this.fetchFingerprint().then((fp) => {
        this.lastFingerprint = fp
      })
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

    if (this.wsConnectedCount > 0) {
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

  // Manual refresh action (can be triggered by button)
  manualRefresh() {
    this.refresh()
  }

  /**
   * Play codec sounds based on task status transitions (MGS Easter egg)
   * agent_spawn: task moves to in_progress (agent started working)
   * agent_complete: task moves to in_review or done (agent finished)
   * agent_error: task gets errored status
   */
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
