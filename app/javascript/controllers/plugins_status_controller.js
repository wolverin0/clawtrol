import { Controller } from "@hotwired/stimulus"

// Fetches and displays OpenClaw gateway plugin status.
// Connects to the /api/v1/gateway/plugins endpoint.
export default class extends Controller {
  static targets = ["container"]
  static values = { url: String }

  connect() {
    this.load()
  }

  refresh() {
    this.load()
  }

  async load() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        credentials: "same-origin"
      })

      if (!response.ok) {
        this.renderError("Gateway unreachable")
        return
      }

      const data = await response.json()

      if (data.error) {
        this.renderError(data.error)
        return
      }

      this.renderPlugins(data.plugins || [], data.gateway_version)
    } catch (e) {
      this.renderError("Failed to fetch")
    }
  }

  renderPlugins(plugins, version) {
    if (plugins.length === 0) {
      this.containerTarget.innerHTML = `
        <div class="text-xs text-content-muted">No plugins detected</div>
        ${version ? `<div class="text-xs text-content-muted mt-1">Gateway v${this.escapeHtml(version)}</div>` : ""}
      `
      return
    }

    const items = plugins.map(p => {
      const isActive = p.enabled !== false && p.status !== "disabled"
      const dotClass = isActive ? "bg-emerald-400" : "bg-gray-500"
      const statusText = this.escapeHtml(p.status || (isActive ? "active" : "disabled"))
      const name = this.escapeHtml(p.name || "unknown")
      const ver = p.version ? ` <span class="text-content-muted">v${this.escapeHtml(p.version)}</span>` : ""

      return `
        <div class="flex items-center justify-between py-1">
          <div class="flex items-center gap-2 min-w-0">
            <div class="w-2 h-2 rounded-full ${dotClass} flex-shrink-0"></div>
            <span class="text-xs text-content truncate">${name}${ver}</span>
          </div>
          <span class="text-xs ${isActive ? 'text-emerald-400' : 'text-content-muted'} flex-shrink-0 ml-2">${statusText}</span>
        </div>
      `
    }).join("")

    this.containerTarget.innerHTML = `
      <div class="space-y-0.5">${items}</div>
      <div class="text-xs text-content-muted mt-2 pt-2 border-t border-border">
        ${plugins.filter(p => p.enabled !== false).length}/${plugins.length} active
        ${version ? ` · Gateway v${this.escapeHtml(version)}` : ""}
      </div>
    `
  }

  renderError(msg) {
    this.containerTarget.innerHTML = `
      <div class="flex items-center gap-2">
        <div class="w-2 h-2 rounded-full bg-red-400"></div>
        <span class="text-xs text-content-muted">${this.escapeHtml(msg)}</span>
      </div>
    `
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = String(str)
    return div.innerHTML
  }
}
