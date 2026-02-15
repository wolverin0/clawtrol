import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "status", "streamMode", "draftChunk", "linkPreviewDisabled", "linkPreviewSmall",
    "commandsJson", "dmScope", "webhookMode", "retryMax", "retryDelay", "proxyUrl"
  ]

  async saveStreaming() {
    await this.save("streaming", {
      stream_mode: this.streamModeTarget.value,
      draft_chunk: this.draftChunkTarget.checked
    })
  }

  async saveLinkPreview() {
    await this.save("linkPreview", {
      disabled: this.linkPreviewDisabledTarget.checked,
      prefer_small: this.linkPreviewSmallTarget.checked
    })
  }

  async saveCommands() {
    let commands
    try {
      commands = JSON.parse(this.commandsJsonTarget.value || "[]")
    } catch {
      this.showStatus("error", "Invalid JSON for commands")
      return
    }
    await this.save("commands", { commands })
  }

  async saveGeneral() {
    await this.save("general", {
      dm_scope: this.dmScopeTarget.value,
      webhook_mode: this.webhookModeTarget.checked
    })
  }

  async saveRetry() {
    await this.save("retry", {
      maxRetries: parseInt(this.retryMaxTarget.value) || 3,
      delayMs: parseInt(this.retryDelayTarget.value) || 1000
    })
  }

  async saveProxy() {
    await this.save("proxy", {
      url: this.proxyUrlTarget.value.trim()
    })
  }

  async save(section, values) {
    this.showStatus("info", `Saving ${section}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/telegram_config/update", {
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
