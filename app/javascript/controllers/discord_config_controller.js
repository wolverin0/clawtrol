import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "maxLines", "dmScope", "streamMode", "reactionMode", "userAllowlist"]

  async saveGeneral() {
    await this.save("general", {
      max_lines: parseInt(this.maxLinesTarget.value) || 40,
      dm_scope: this.dmScopeTarget.value,
      stream_mode: this.streamModeTarget.value
    })
  }

  async saveActions() {
    const toggles = this.element.querySelectorAll(".discord-action-toggle")
    const actions = {}
    toggles.forEach(el => {
      actions[el.dataset.actionName] = el.checked
    })
    await this.save("actions", { actions })
  }

  async saveReactions() {
    await this.save("reactions", { mode: this.reactionModeTarget.value })
  }

  async saveUsers() {
    const text = this.userAllowlistTarget.value || ""
    const allowFrom = text.split("\n").map(l => l.trim()).filter(l => l.length > 0)
    await this.save("users", { allowFrom })
  }

  async save(section, values) {
    this.showStatus("info", `Saving ${section}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/discord_config/update", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ section, values })
      })
      const data = await resp.json()
      if (data.success) {
        this.showStatus("success", data.message || `${section} saved`)
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
