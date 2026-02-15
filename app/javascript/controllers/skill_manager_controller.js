import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "installName", "configPanel", "envInput"]

  async toggleSkill(event) {
    const btn = event.currentTarget
    const skill = btn.dataset.skill
    const currentlyEnabled = btn.dataset.enabled === "true"
    const newEnabled = !currentlyEnabled

    this.showStatus("info", `${newEnabled ? "Enabling" : "Disabling"} ${skill}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(`/skills/${encodeURIComponent(skill)}/toggle`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ enabled: newEnabled })
      })
      const data = await resp.json()
      if (data.success) {
        this.showStatus("success", data.message || `${skill} ${newEnabled ? "enabled" : "disabled"}`)
        setTimeout(() => location.reload(), 1500)
      } else {
        this.showStatus("error", data.error || "Toggle failed")
      }
    } catch (e) {
      this.showStatus("error", `Error: ${e.message}`)
    }
  }

  async installSkill() {
    const input = this.installNameTarget
    const name = (input.value || "").trim()
    if (!name) { this.showStatus("error", "Enter a skill name"); return }

    this.showStatus("info", `Installing ${name}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/skills/install", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ skill_name: name })
      })
      const data = await resp.json()
      if (data.success) {
        this.showStatus("success", data.message || `${name} installed`)
        input.value = ""
        setTimeout(() => location.reload(), 1500)
      } else {
        this.showStatus("error", data.error || "Install failed")
      }
    } catch (e) {
      this.showStatus("error", `Error: ${e.message}`)
    }
  }

  async uninstallSkill(event) {
    const skill = event.currentTarget.dataset.skill
    if (!confirm(`Remove ${skill} from config?`)) return

    this.showStatus("info", `Removing ${skill}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(`/skills/${encodeURIComponent(skill)}`, {
        method: "DELETE",
        headers: { "X-CSRF-Token": token }
      })
      const data = await resp.json()
      if (data.success) {
        this.showStatus("success", data.message || `${skill} removed`)
        setTimeout(() => location.reload(), 1500)
      } else {
        this.showStatus("error", data.error || "Remove failed")
      }
    } catch (e) {
      this.showStatus("error", `Error: ${e.message}`)
    }
  }

  showConfig(event) {
    const skill = event.currentTarget.dataset.skill
    this.configPanelTargets.forEach(panel => {
      if (panel.dataset.skillPanel === skill) {
        panel.classList.toggle("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }

  hideConfig(event) {
    const skill = event.currentTarget.dataset.skill
    this.configPanelTargets.forEach(panel => {
      if (panel.dataset.skillPanel === skill) panel.classList.add("hidden")
    })
  }

  async saveConfig(event) {
    const skill = event.currentTarget.dataset.skill
    const textarea = this.envInputTargets.find(t => t.dataset.skillEnv === skill)
    const envVars = (textarea?.value || "").trim() || "{}"

    try {
      JSON.parse(envVars)
    } catch {
      this.showStatus("error", "Invalid JSON in env vars")
      return
    }

    this.showStatus("info", `Saving env vars for ${skill}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(`/skills/${encodeURIComponent(skill)}/configure`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ env_vars: envVars })
      })
      const data = await resp.json()
      if (data.success) {
        this.showStatus("success", data.message || `Env saved for ${skill}`)
        this.hideConfig(event)
        setTimeout(() => location.reload(), 1500)
      } else {
        this.showStatus("error", data.error || "Save failed")
      }
    } catch (e) {
      this.showStatus("error", `Error: ${e.message}`)
    }
  }

  showStatus(type, message) {
    const el = this.statusTarget
    el.classList.remove("hidden", "bg-green-500/20", "text-green-400", "bg-red-500/20", "text-red-400", "bg-blue-500/20", "text-blue-400")

    const styles = {
      success: "bg-green-500/20 text-green-400",
      error: "bg-red-500/20 text-red-400",
      info: "bg-blue-500/20 text-blue-400"
    }
    el.className = `text-xs px-3 py-2 rounded-md ${styles[type] || styles.info}`
    el.textContent = message
  }
}
