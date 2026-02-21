import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tab", "panel", "soulTextarea", "agentsTextarea", "taskPrompt", "taskTimeout",
    "sendTaskButton", "taskStatus", "taskResult", "logsOutput", "logsToggleButton", "globalStatus"
  ]

  static values = {
    id: String,
    taskUrl: String,
    logsUrl: String,
    tasksUrl: String,
    soulUrl: String,
    agentsUrl: String,
    template: String
  }

  connect() {
    this.activeTab = "overview"
    this.logsInterval = null
    this.highlightTabs()
    this.showPanel("overview")
    this.prefillTaskPrompt()
  }

  disconnect() {
    this.stopLogsPolling()
  }

  switchTab(event) {
    const tab = event.currentTarget.dataset.tab
    if (!tab) return

    this.activeTab = tab
    this.highlightTabs()
    this.showPanel(tab)

    if (tab === "logs") {
      this.refreshLogs()
    } else if (tab === "task") {
      this.prefillTaskPrompt()
    } else {
      this.stopLogsPolling()
    }
  }

  async saveSoul() {
    await this.saveFile(this.soulUrlValue, this.soulTextareaTarget.value, "SOUL.md saved ✅")
  }

  async saveAgents() {
    await this.saveFile(this.agentsUrlValue, this.agentsTextareaTarget.value, "AGENTS.md saved ✅")
  }

  async dispatchTask() {
    const prompt = this.taskPromptTarget.value.trim()
    if (!prompt) {
      this.taskStatusTarget.textContent = "Prompt is required"
      return
    }

    this.sendTaskButtonTarget.disabled = true
    this.taskStatusTarget.textContent = "Running..."
    this.globalStatusTarget.textContent = "Dispatching task to agent..."

    try {
      const payload = {
        prompt,
        timeout: parseInt(this.taskTimeoutTarget.value || "60", 10)
      }

      const response = await this.request(this.taskUrlValue, {
        method: "POST",
        body: JSON.stringify(payload)
      })

      const task = response.task || {}
      this.taskResultTarget.textContent = task.result || "(no output)"
      this.taskStatusTarget.textContent = `Done in ${task.duration_ms || 0}ms · exit ${task.exit_code}`
      this.globalStatusTarget.textContent = "Task completed."
    } catch (error) {
      this.taskStatusTarget.textContent = `Error: ${error.message}`
      this.globalStatusTarget.textContent = "Task failed."
    } finally {
      this.sendTaskButtonTarget.disabled = false
    }
  }

  async refreshLogs() {
    try {
      const response = await this.request(`${this.logsUrlValue}?tail=200`, { method: "GET" })
      this.logsOutputTarget.textContent = response.output || response.error || "(no logs)"
      this.globalStatusTarget.textContent = `Logs refreshed at ${new Date().toLocaleTimeString()}`
    } catch (error) {
      this.logsOutputTarget.textContent = `Failed to load logs: ${error.message}`
      this.globalStatusTarget.textContent = "Log refresh failed."
    }
  }

  toggleLogs() {
    if (this.logsInterval) {
      this.stopLogsPolling()
      return
    }

    this.logsToggleButtonTarget.textContent = "Auto-refresh: on"
    this.logsInterval = setInterval(() => this.refreshLogs(), 4000)
    this.refreshLogs()
  }

  stopLogsPolling() {
    if (!this.logsInterval) {
      this.logsToggleButtonTarget.textContent = "Auto-refresh: off"
      return
    }

    clearInterval(this.logsInterval)
    this.logsInterval = null
    this.logsToggleButtonTarget.textContent = "Auto-refresh: off"
  }

  async saveFile(url, content, successLabel) {
    this.globalStatusTarget.textContent = "Saving..."

    try {
      await this.request(url, {
        method: "PATCH",
        body: JSON.stringify({ content })
      })
      this.globalStatusTarget.textContent = successLabel
    } catch (error) {
      this.globalStatusTarget.textContent = `Save failed: ${error.message}`
    }
  }

  showPanel(tabName) {
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.panel !== tabName)
    })
  }

  highlightTabs() {
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tab === this.activeTab
      tab.classList.toggle("bg-bg-base", active)
      tab.classList.toggle("text-content", active)
      tab.classList.toggle("border-border", active)
      tab.classList.toggle("text-content-muted", !active)
    })
  }

  async request(url, options = {}) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      method: options.method || "GET",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": token
      },
      body: options.body
    })

    const data = await response.json()
    if (!response.ok) {
      throw new Error(data.error || `HTTP ${response.status}`)
    }

    return data
  }

  prefillTaskPrompt() {
    if (!this.hasTaskPromptTarget) return
    if (this.taskPromptTarget.value.trim()) return
    const template = this.templateValue?.trim()
    if (template) this.taskPromptTarget.value = template
  }
}
