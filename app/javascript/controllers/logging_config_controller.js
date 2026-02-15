import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "status", "level", "consoleLevel", "consoleStyle", "file", "redact",
    "debugEnabled", "debugBash", "debugEval",
    "tailLevel", "tailLines", "logOutput"
  ]

  async saveLogging() {
    await this.save("logging", {
      level: this.levelTarget.value,
      console_level: this.consoleLevelTarget.value,
      console_style: this.consoleStyleTarget.value,
      file: this.fileTarget.value.trim(),
      redact_sensitive: this.redactTarget.checked
    })
  }

  async saveDebug() {
    await this.save("debug", {
      enabled: this.debugEnabledTarget.checked,
      bash: this.debugBashTarget.checked,
      allow_eval: this.debugEvalTarget.checked
    })
  }

  async loadLogs() {
    const lines = parseInt(this.tailLinesTarget.value) || 50
    const level = this.tailLevelTarget.value

    this.logOutputTarget.innerHTML = '<p class="text-sm text-content-muted text-center">Loading…</p>'

    try {
      const params = new URLSearchParams({ lines, level })
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(`/logging_config/tail?${params}`, {
        headers: { "X-CSRF-Token": token }
      })
      const data = await resp.json()

      if (data.lines && data.lines.length > 0) {
        const html = data.lines.map(line => {
          let colorClass = "text-content-muted"
          if (line.includes("ERROR") || line.includes("error")) colorClass = "text-red-400"
          else if (line.includes("WARN") || line.includes("warn")) colorClass = "text-yellow-400"
          else if (line.includes("INFO") || line.includes("info")) colorClass = "text-blue-400"
          else if (line.includes("DEBUG") || line.includes("debug")) colorClass = "text-gray-400"
          return `<div class="text-[10px] font-mono ${colorClass} leading-relaxed whitespace-pre-wrap break-all">${this.escapeHtml(line)}</div>`
        }).join("")

        this.logOutputTarget.innerHTML = `
          <div class="text-[10px] text-content-muted mb-2">Source: ${this.escapeHtml(data.source)} — ${data.count} lines</div>
          <div class="max-h-96 overflow-y-auto bg-bg-base rounded p-3 space-y-0.5">${html}</div>
        `
      } else {
        this.logOutputTarget.innerHTML = '<p class="text-sm text-content-muted text-center">No log lines found. Log file may not be configured or accessible.</p>'
      }
    } catch (e) {
      this.logOutputTarget.innerHTML = `<p class="text-sm text-red-400 text-center">Error: ${this.escapeHtml(e.message)}</p>`
    }
  }

  async save(section, values) {
    this.showStatus("info", `Saving ${section}…`)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/logging_config/update", {
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

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  showStatus(type, message) {
    const el = this.statusTarget
    el.classList.remove("hidden")
    const styles = { success: "bg-green-500/20 text-green-400", error: "bg-red-500/20 text-red-400", info: "bg-blue-500/20 text-blue-400" }
    el.className = `text-xs px-3 py-2 rounded-md ${styles[type] || styles.info}`
    el.textContent = message
  }
}
