import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "status"]
  static values = { url: String, interval: { type: Number, default: 5000 } }

  connect() {
    this.refresh = this.refresh.bind(this)
    this.handleVisibility = this.handleVisibility.bind(this)
    this.timer = window.setInterval(this.refresh, this.intervalValue)
    document.addEventListener("visibilitychange", this.handleVisibility)
  }

  disconnect() {
    window.clearInterval(this.timer)
    document.removeEventListener("visibilitychange", this.handleVisibility)
  }

  handleVisibility() {
    if (document.visibilityState === "visible") this.refresh()
  }

  async refresh() {
    if (this.loading || document.visibilityState === "hidden") return

    this.loading = true
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html" },
        credentials: "same-origin",
        cache: "no-store"
      })
      if (!response.ok) throw new Error(`thread HTTP ${response.status}`)
      this.updateMessages(await response.text())
      this.showStatus("Live updates on", "text-green-400")
    } catch (_error) {
      this.showStatus("Live update delayed", "text-yellow-400")
    } finally {
      this.loading = false
    }
  }

  updateMessages(html) {
    const documentFragment = new DOMParser().parseFromString(html, "text/html")
    const next = documentFragment.querySelector("#task-thread-messages")
    if (!next || next.dataset.version === this.messagesTarget.dataset.version) return

    this.messagesTarget.innerHTML = next.innerHTML
    this.messagesTarget.dataset.version = next.dataset.version
  }

  showStatus(text, colorClass) {
    this.statusTarget.textContent = text
    this.statusTarget.classList.remove("text-green-400", "text-yellow-400")
    this.statusTarget.classList.add(colorClass)
  }
}
