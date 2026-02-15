import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "mode", "debounce", "watchConfig"]

  async save() {
    this.showStatus("info", "Saving hot reload config…")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/hot_reload/update", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({
          values: {
            mode: this.modeTarget.value,
            debounce_ms: parseInt(this.debounceTarget.value) || 2000,
            watch_config: this.watchConfigTarget.checked
          }
        })
      })
      const data = await resp.json()
      if (data.success) {
        this.showStatus("success", data.message || "Saved")
        setTimeout(() => location.reload(), 2000)
      } else {
        this.showStatus("error", data.error || "Save failed")
      }
    } catch (e) {
      this.showStatus("error", `Error: ${e.message}`)
    }
  }

  showStatus(type, message) {
    const el = this.statusTarget
    el.classList.remove("hidden")
    const styles = { success: "bg-green-500/20 text-green-400", error: "bg-red-500/20 text-red-400", info: "bg-blue-500/20 text-blue-400" }
    el.className = `text-xs px-3 py-2 rounded-md ${styles[type] || styles.info}`
    el.textContent = message
  }
}
