import { Controller } from "@hotwired/stimulus"

/**
 * Block Streaming Config controller.
 * Collects form values and saves to gateway config.
 */
export default class extends Controller {
  static targets = ["enabled", "chunkSize", "coalesceMs", "splitOn", "jsonPreview", "status"]

  async save() {
    const config = this.buildConfig()
    this.showStatus("Saving streaming config...", "info")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/streaming/update", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({ streaming_config: JSON.stringify(config) })
      })

      const data = await response.json()
      if (data.success) {
        this.showStatus(data.message || "Saved!", "success")
        if (this.hasJsonPreviewTarget) {
          this.jsonPreviewTarget.textContent = JSON.stringify(config, null, 2)
        }
      } else {
        this.showStatus(data.error || "Save failed", "error")
      }
    } catch (err) {
      this.showStatus(`Error: ${err.message}`, "error")
    }
  }

  buildConfig() {
    const config = {
      enabled: this.enabledTarget.value === "true",
      chunkSize: parseInt(this.chunkSizeTarget.value, 10) || 2000,
      coalesceMs: parseInt(this.coalesceMsTarget.value, 10) || 500,
      splitOn: this.splitOnTarget.value || "paragraph"
    }

    // Collect per-channel overrides
    const perChannel = {}
    this.element.querySelectorAll("[data-channel]").forEach(input => {
      const channel = input.dataset.channel
      const field = input.dataset.field
      const value = parseInt(input.value, 10)
      if (!isNaN(value) && value > 0) {
        if (!perChannel[channel]) perChannel[channel] = {}
        perChannel[channel][field] = value
      }
    })

    if (Object.keys(perChannel).length > 0) {
      config.perChannel = perChannel
    }

    return config
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.textContent = message
    el.classList.remove("hidden", "bg-green-500/20", "text-green-400",
                        "bg-red-500/20", "text-red-400", "bg-blue-500/20", "text-blue-400")
    if (type === "success") el.classList.add("bg-green-500/20", "text-green-400")
    else if (type === "error") el.classList.add("bg-red-500/20", "text-red-400")
    else el.classList.add("bg-blue-500/20", "text-blue-400")
    el.classList.remove("hidden")
    if (type !== "error") setTimeout(() => el.classList.add("hidden"), 5000)
  }
}
