import { Controller } from "@hotwired/stimulus"

/**
 * Live Events polling controller.
 * Polls gateway status every 10 seconds and updates the UI.
 */
export default class extends Controller {
  static targets = ["pollIndicator", "toggleBtn"]
  static values = { pollUrl: String }

  connect() {
    this.polling = true
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollTimer = setInterval(() => {
      if (this.polling) this.poll()
    }, 10000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  togglePolling() {
    this.polling = !this.polling

    if (this.hasToggleBtnTarget) {
      this.toggleBtnTarget.textContent = this.polling ? "⏸ Pause" : "▶ Resume"
    }

    if (this.hasPollIndicatorTarget) {
      const dot = this.pollIndicatorTarget.querySelector("span:first-child")
      const text = this.pollIndicatorTarget.querySelector("span:last-child")
      if (dot) {
        dot.classList.toggle("animate-pulse", this.polling)
        dot.classList.toggle("bg-green-500", this.polling)
        dot.classList.toggle("bg-gray-500", !this.polling)
      }
      if (text) {
        text.textContent = this.polling ? "Live" : "Paused"
      }
    }
  }

  async poll() {
    try {
      const url = this.pollUrlValue || "/live/poll.json"
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return

      // Data received — could update DOM here in future
      // For now, the page auto-refreshes via Turbo if needed
    } catch {
      // Silently ignore poll failures
    }
  }
}
