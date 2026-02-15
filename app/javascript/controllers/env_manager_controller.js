import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "template", "testResult", "rawContent"]

  async testSubstitution() {
    const template = this.templateTarget.value.trim()
    if (!template) { this.showStatus("error", "Enter a template"); return }

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/env_manager/test", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ template })
      })
      const data = await resp.json()

      const el = this.testResultTarget
      el.classList.remove("hidden")

      if (data.success) {
        el.innerHTML = `
          <div class="space-y-2">
            <div>
              <span class="text-[10px] text-content-muted">Input:</span>
              <pre class="text-xs font-mono text-content mt-0.5">${this.escapeHtml(data.template)}</pre>
            </div>
            <div>
              <span class="text-[10px] text-content-muted">Resolved:</span>
              <pre class="text-xs font-mono text-green-400 mt-0.5">${this.escapeHtml(data.resolved)}</pre>
            </div>
            <div>
              <span class="text-[10px] text-content-muted">Variables found:</span>
              <span class="text-xs font-mono text-accent">${data.vars_found.join(", ") || "none"}</span>
            </div>
          </div>
        `
      } else {
        el.innerHTML = `<p class="text-xs text-red-400">${this.escapeHtml(data.error)}</p>`
      }
    } catch (e) {
      this.showStatus("error", `Error: ${e.message}`)
    }
  }

  async loadRaw() {
    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch("/env_manager/file", {
        headers: { "X-CSRF-Token": token }
      })
      const data = await resp.json()

      const el = this.rawContentTarget
      if (data.exists && data.content) {
        el.innerHTML = `
          <div class="text-[10px] text-content-muted mb-2">${data.line_count} lines</div>
          <pre class="text-[10px] text-content font-mono bg-bg-base rounded p-3 overflow-x-auto max-h-64 overflow-y-auto whitespace-pre-wrap">${this.escapeHtml(data.content)}</pre>
        `
      } else {
        el.innerHTML = '<p class="text-sm text-content-muted text-center">.env file not found.</p>'
      }
    } catch (e) {
      this.rawContentTarget.innerHTML = `<p class="text-sm text-red-400 text-center">Error: ${this.escapeHtml(e.message)}</p>`
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
