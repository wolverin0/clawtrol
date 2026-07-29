import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = { interval: { type: Number, default: 5000 }, url: String }

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    if (this.inFlight || document.hidden) return

    this.inFlight = true
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/html" }, cache: "no-store" })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.updateRegions(await response.text())
      this.setStatus("Live cockpit · updated just now", "text-green-400")
    } catch (_error) {
      this.setStatus("Live cockpit update delayed", "text-yellow-400")
    } finally {
      this.inFlight = false
    }
  }

  updateRegions(html) {
    const next = document.createElement("div")
    next.innerHTML = html
    next.querySelectorAll("[data-control-room-live-region]").forEach((region) => {
      const name = region.dataset.controlRoomLiveRegion
      const current = [...this.element.querySelectorAll("[data-control-room-live-region]")]
        .find((candidate) => candidate.dataset.controlRoomLiveRegion === name)
      if (current) {
        this.syncRegionAttributes(current, region)
        current.innerHTML = region.innerHTML
      }
    })
  }

  syncRegionAttributes(current, next) {
    const names = [
      "class", "role", "data-source-count", "data-rendered-count",
      "data-open-source-count", "data-unclassified-count"
    ]
    names.forEach((name) => {
      if (next.hasAttribute(name)) current.setAttribute(name, next.getAttribute(name))
      else current.removeAttribute(name)
    })
  }

  setStatus(message, tone) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("text-green-400", "text-yellow-400")
    this.statusTarget.classList.add(tone)
  }
}
