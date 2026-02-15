import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for Exec Approvals Manager.
 * Handles add/remove/bulk import of exec command approvals.
 */
export default class extends Controller {
  static targets = ["nodeSelect", "commandInput", "bulkNode", "bulkCommands", "status"]

  async addCommand() {
    const nodeId = this.nodeSelectTarget.value
    const command = this.commandInputTarget.value.trim()

    if (!command) {
      this.showStatus("Enter a command", "error")
      return
    }

    await this.postAction("/exec_approvals/add", { node_id: nodeId, command })
    this.commandInputTarget.value = ""
  }

  async removeCommand(event) {
    const nodeId = event.currentTarget.dataset.node
    const command = event.currentTarget.dataset.command

    if (!confirm(`Remove "${command}" from ${nodeId}?`)) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch("/exec_approvals/remove", {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({ node_id: nodeId, command })
      })

      const data = await response.json()
      if (data.success) {
        this.showStatus(data.message || "Removed!", "success")
        // Remove the element from DOM
        event.currentTarget.closest("[class*='flex items-center gap-1']").remove()
      } else {
        this.showStatus(data.error || "Remove failed", "error")
      }
    } catch (err) {
      this.showStatus(`Error: ${err.message}`, "error")
    }
  }

  async bulkImport() {
    const nodeId = this.bulkNodeTarget.value
    const commands = this.bulkCommandsTarget.value.trim()

    if (!commands) {
      this.showStatus("Enter commands (one per line)", "error")
      return
    }

    await this.postAction("/exec_approvals/bulk_import", { node_id: nodeId, commands })
    this.bulkCommandsTarget.value = ""
  }

  async postAction(url, body) {
    this.showStatus("Saving...", "info")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(url, {
        method: "POST",
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
        setTimeout(() => window.location.reload(), 2000)
      } else {
        this.showStatus(data.error || "Failed", "error")
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
                        "bg-red-500/20", "text-red-400", "bg-blue-500/20", "text-blue-400")
    if (type === "success") el.classList.add("bg-green-500/20", "text-green-400")
    else if (type === "error") el.classList.add("bg-red-500/20", "text-red-400")
    else el.classList.add("bg-blue-500/20", "text-blue-400")
    el.classList.remove("hidden")
    if (type !== "error") setTimeout(() => el.classList.add("hidden"), 5000)
  }
}
