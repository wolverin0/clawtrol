import { Controller } from "@hotwired/stimulus"

/**
 * Gateway Config Editor controller.
 * Handles config editing, apply/patch actions, and restart.
 */
export default class extends Controller {
  static targets = ["editor", "status", "sectionContent"]

  connect() {
    this.modified = false
  }

  markModified() {
    this.modified = true
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "⚠️ Unsaved changes"
      this.statusTarget.classList.remove("hidden")
    }
  }

  async applyConfig() {
    if (!confirm("Apply full config? This will REPLACE the entire config and restart the gateway.")) return
    await this.sendConfig("/gateway/config/apply", "apply")
  }

  async patchConfig() {
    if (!confirm("Patch config? This will MERGE with the existing config and restart.")) return
    await this.sendConfig("/gateway/config/patch", "patch")
  }

  async restart() {
    if (!confirm("Restart the OpenClaw gateway?")) return

    this.setStatus("Restarting...", "text-yellow-500")
    try {
      const response = await fetch("/gateway/config/restart", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ reason: "Manual restart from ClawTrol Config Editor" })
      })
      const data = await response.json()
      if (data.success) {
        this.setStatus("✅ " + data.message, "text-green-500")
      } else {
        this.setStatus("❌ " + (data.error || "Restart failed"), "text-red-500")
      }
    } catch (err) {
      this.setStatus("❌ Request failed: " + err.message, "text-red-500")
    }
  }

  async sendConfig(url, action) {
    const raw = this.hasEditorTarget ? this.editorTarget.value : ""
    if (!raw.trim()) {
      this.setStatus("❌ Config is empty", "text-red-500")
      return
    }

    this.setStatus(`Applying ${action}...`, "text-yellow-500")
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ config_raw: raw, reason: `${action} from ClawTrol Config Editor` })
      })
      const data = await response.json()
      if (data.success) {
        this.modified = false
        this.setStatus("✅ " + data.message, "text-green-500")
      } else {
        this.setStatus("❌ " + (data.error || `${action} failed`), "text-red-500")
      }
    } catch (err) {
      this.setStatus("❌ Request failed: " + err.message, "text-red-500")
    }
  }

  toggleSection(event) {
    const sectionId = event.currentTarget.dataset.section
    const content = document.getElementById(`section-${sectionId}`)
    if (content) {
      content.classList.toggle("hidden")
      const icon = event.currentTarget.querySelector(".chevron")
      if (icon) icon.classList.toggle("rotate-90")
    }
  }

  copyToEditor(event) {
    const json = event.currentTarget.dataset.json
    if (this.hasEditorTarget && json) {
      this.editorTarget.value = json
      this.markModified()
      this.editorTarget.scrollIntoView({ behavior: "smooth" })
    }
  }

  setStatus(text, colorClass) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      this.statusTarget.className = `text-sm font-medium ${colorClass}`
      this.statusTarget.classList.remove("hidden")
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
  }
}
