import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.startRefreshing()
  }

  disconnect() {
    this.stopRefreshing()
  }

  startRefreshing() {
    this.refreshTimer = setInterval(() => {
      // Use Turbo to refresh the page content without a full reload
      // This is more efficient and preserves scroll position.
      // Note: This requires Turbo to be properly configured.
      // A simple location.reload() is a fallback.
      if (typeof Turbo !== 'undefined') {
        Turbo.visit(window.location.href, { action: "replace" })
      } else {
        location.reload()
      }
    }, 15000) // Refresh every 15 seconds
  }

  stopRefreshing() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }
}
