import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for editing individual agent configurations.
 * Handles expand/collapse and saving agent config changes via PATCH.
 */
export default class extends Controller {
  static targets = ["panel", "chevron", "workspace", "model", "toolProfile",
                     "compactionMode", "systemPrompt", "status"]
  static values = { agentId: String }

  toggle() {
    const panel = this.panelTarget
    const chevron = this.chevronTarget

    if (panel.classList.contains("hidden")) {
      panel.classList.remove("hidden")
      chevron.classList.add("rotate-180")
    } else {
      panel.classList.add("hidden")
      chevron.classList.remove("rotate-180")
    }
  }

  async save() {
    const body = {
      agent_id: this.agentIdValue,
      workspace: this.hasWorkspaceTarget ? this.workspaceTarget.value : "",
      model: this.hasModelTarget ? this.modelTarget.value : "",
      tool_profile: this.hasToolProfileTarget ? this.toolProfileTarget.value : "",
      compaction_mode: this.hasCompactionModeTarget ? this.compactionModeTarget.value : "",
      system_prompt: this.hasSystemPromptTarget ? this.systemPromptTarget.value : ""
    }

    this.showStatus("Saving...", "info")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/agents/config/update_agent", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify(body)
      })

      const data = await response.json()

      if (data.success) {
        this.showStatus(data.message || "Saved!", "success")
      } else {
        this.showStatus(data.error || "Save failed", "error")
      }
    } catch (err) {
      this.showStatus(`Error: ${err.message}`, "error")
    }
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return

    const el = this.statusTarget
    el.textContent = message
    el.classList.remove("hidden", "bg-green-500/20", "text-green-400",
                        "bg-red-500/20", "text-red-400",
                        "bg-blue-500/20", "text-blue-400")

    if (type === "success") {
      el.classList.add("bg-green-500/20", "text-green-400")
    } else if (type === "error") {
      el.classList.add("bg-red-500/20", "text-red-400")
    } else {
      el.classList.add("bg-blue-500/20", "text-blue-400")
    }

    el.classList.remove("hidden")

    if (type !== "error") {
      setTimeout(() => el.classList.add("hidden"), 5000)
    }
  }
}
