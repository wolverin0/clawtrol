import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "status", "filterButton", "tailCount", "autoButton"]
  static values = { url: String }

  connect() {
    this.activeFilter = "ALL"
    this.rawOutput = this.outputTarget.textContent
    this.autoInterval = null
  }

  disconnect() {
    this.stopAuto()
  }

  async refresh() {
    const tail = this.tailCountTarget?.value || 200
    this.statusTarget.textContent = "Loading..."

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(`${this.urlValue}?tail=${tail}`, {
        headers: { "Accept": "application/json", "X-CSRF-Token": token }
      })
      const data = await resp.json()
      this.rawOutput = data.output || "(no logs)"
      this.applyFilter()
      this.statusTarget.textContent = `Refreshed at ${new Date().toLocaleTimeString()}`
      this.scrollToBottom()
    } catch (e) {
      this.statusTarget.textContent = `Error: ${e.message}`
    }
  }

  setFilter(event) {
    this.activeFilter = event.currentTarget.dataset.level
    this.filterButtonTargets.forEach(btn => {
      const active = btn.dataset.level === this.activeFilter
      btn.classList.toggle("bg-bg-base", active)
      btn.classList.toggle("text-content", active)
      btn.classList.toggle("border-border", active)
      btn.classList.toggle("text-content-muted", !active)
    })
    this.applyFilter()
  }

  applyFilter() {
    if (this.activeFilter === "ALL") {
      this.outputTarget.innerHTML = this.colorize(this.rawOutput)
      return
    }

    const keyword = this.activeFilter.toLowerCase()
    const lines = this.rawOutput.split("\n").filter(line =>
      line.toLowerCase().includes(keyword)
    )
    this.outputTarget.innerHTML = this.colorize(lines.join("\n") || `(no ${this.activeFilter} lines)`)
  }

  colorize(text) {
    return text
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/^(.*\b(?:error|fatal|panic)\b.*)$/gim, '<span class="text-red-400">$1</span>')
      .replace(/^(.*\b(?:warn(?:ing)?)\b.*)$/gim, '<span class="text-yellow-300">$1</span>')
      .replace(/^(.*\b(?:info)\b.*)$/gim, '<span class="text-blue-300">$1</span>')
  }

  toggleAutoRefresh() {
    if (this.autoInterval) {
      this.stopAuto()
    } else {
      this.autoInterval = setInterval(() => this.refresh(), 4000)
      this.autoButtonTarget.textContent = "Auto: on"
      this.refresh()
    }
  }

  stopAuto() {
    if (this.autoInterval) {
      clearInterval(this.autoInterval)
      this.autoInterval = null
    }
    this.autoButtonTarget.textContent = "Auto: off"
  }

  scrollToBottom() {
    this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  }
}
