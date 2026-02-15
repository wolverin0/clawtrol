import { Controller } from "@hotwired/stimulus"

// Live refresh + quick actions for the paired nodes page.
export default class extends Controller {
  static targets = ["grid"]
  static values = { url: String }

  connect() {
    // Auto-refresh every 30 seconds
    this.refreshInterval = setInterval(() => this.refresh(), 30000)
  }

  disconnect() {
    if (this.refreshInterval) clearInterval(this.refreshInterval)
  }

  refresh() {
    // Turbo visit same page for full re-render
    if (typeof Turbo !== "undefined") {
      Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }

  async notify(event) {
    const nodeId = event.currentTarget.dataset.nodeId
    const title = prompt("Notification title:")
    if (!title) return

    const body = prompt("Notification body:")
    if (body === null) return

    try {
      const response = await this.postAction(`/api/v1/gateway/nodes/${encodeURIComponent(nodeId)}/notify`, {
        title: title,
        body: body || ""
      })
      if (response.ok) {
        this.flash("✅ Notification sent")
      } else {
        this.flash("❌ Failed to send notification")
      }
    } catch (e) {
      this.flash("❌ Error: " + e.message)
    }
  }

  async cameraSnap(event) {
    const nodeId = event.currentTarget.dataset.nodeId
    this.flash(`📷 Camera snap requested for ${nodeId}...`)
    // This would call the gateway camera API — placeholder for now
  }

  async locate(event) {
    const nodeId = event.currentTarget.dataset.nodeId
    this.flash(`📍 Location requested for ${nodeId}...`)
    // This would call the gateway location API — placeholder for now
  }

  async postAction(url, body) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
      },
      credentials: "same-origin",
      body: JSON.stringify(body)
    })
  }

  flash(msg) {
    // Brief toast notification
    const toast = document.createElement("div")
    toast.className = "fixed bottom-4 right-4 bg-bg-elevated border border-border text-content text-sm px-4 py-2 rounded-lg shadow-lg z-50 transition-opacity duration-300"
    toast.textContent = msg
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.style.opacity = "0"
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }
}
