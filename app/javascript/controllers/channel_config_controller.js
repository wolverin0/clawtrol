import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "status", "chatMode", "dmScope", "serverUrl", "team",
    "socketMode", "threadMode",
    "reactionMode", "groupHandling"
  ]
  static values = { channel: String }

  async saveMattermost() {
    await this.save({
      chat_mode: this.chatModeTarget.value,
      dm_scope: this.dmScopeTarget.value,
      server_url: this.serverUrlTarget.value.trim(),
      team: this.teamTarget.value.trim()
    })
  }

  async saveSlack() {
    await this.save({
      socket_mode: this.socketModeTarget.checked,
      thread_mode: this.threadModeTarget.value,
      dm_scope: this.dmScopeTarget.value
    })
  }

  async saveSignal() {
    await this.save({
      reaction_mode: this.reactionModeTarget.value,
      group_handling: this.groupHandlingTarget.value,
      dm_scope: this.dmScopeTarget.value
    })
  }

  async save(values) {
    const channel = this.channelValue
    this.showStatus("info", `Saving ${channel} config…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(`/channel_config/${channel}/update`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ values })
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
