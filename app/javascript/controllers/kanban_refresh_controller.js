import { Controller } from "@hotwired/stimulus"
import { subscribeToKanban } from "channels"

/**
 * Auto-refresh controller for kanban board
 * Uses WebSocket for real-time updates with polling as fallback
 */
export default class extends Controller {
  static values = {
    boardId: Number,
    interval: { type: Number, default: 15000 }, // 15 seconds default (fallback polling)
    apiPath: String
  }

  static targets = ["indicator"]

  connect() {
    this.lastFingerprint = null
    this.isRefreshing = false
    this.isPaused = false
    this.wsConnected = false
    this.subscription = null
    
    // Get initial fingerprint
    this.fetchFingerprint().then(fp => {
      this.lastFingerprint = fp
    })
    
    // Try WebSocket first
    this.connectWebSocket()
    
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

  connectWebSocket() {
    if (!this.boardIdValue) return
    
    try {
      this.subscription = subscribeToKanban(this.boardIdValue, {
        onConnected: () => {
          this.wsConnected = true
          this.stopPolling() // Disable polling when WebSocket is active
          console.log("[KanbanRefresh] WebSocket connected, polling disabled")
        },
        onDisconnected: () => {
          this.wsConnected = false
          this.startPolling() // Re-enable polling as fallback
          console.log("[KanbanRefresh] WebSocket disconnected, polling enabled")
        },
        onReceived: (data) => {
          // Trigger refresh when we get a message
          if (data.type === "refresh" || data.type === "create" || data.type === "update" || data.type === "destroy") {
            this.refresh()
          }
        }
      })
    } catch (error) {
      console.warn("[KanbanRefresh] WebSocket connection failed, using polling:", error)
      this.startPolling()
    }
  }

  disconnectWebSocket() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    this.wsConnected = false
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
      if (!this.wsConnected) {
        this.checkForChanges()
      }
    }
  }

  handleTurboLoad() {
    // Update fingerprint after a Turbo navigation
    this.fetchFingerprint().then(fp => {
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
        "Accept": "application/json"
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
      this.fetchFingerprint().then(fp => {
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

  // Manual refresh action (can be triggered by button)
  manualRefresh() {
    this.refresh()
  }
}
