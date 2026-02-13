import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "count", "playing", "modal"]

  connect() {
    this.updateStats()
    this.refreshTimer = setInterval(() => this.refreshMetrics(), 15000)
  }

  disconnect() {
    if (this.refreshTimer) clearInterval(this.refreshTimer)
  }

  toggle(event) {
    event.currentTarget.classList.toggle("selected")
    this.updateStats()
  }

  openModal() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
  }

  overlayClose(event) {
    if (event.target === this.modalTarget) this.closeModal()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  play(event) {
    this.postAction(event, "play")
  }

  pause(event) {
    this.postAction(event, "pause")
  }

  stop(event) {
    this.postAction(event, "stop")
  }

  postAction(event, action) {
    event.stopPropagation()
    const id = event.currentTarget.dataset.loopId
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    fetch(`/factory/${id}/${action}`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken || "",
        "Accept": "application/json"
      }
    })
      .then(() => this.refreshMetrics())
      .catch(() => {})
  }

  refreshMetrics() {
    this.cardTargets.forEach((card) => {
      const id = card.dataset.loopId
      fetch(`/api/v1/factory/loops/${id}/metrics`, { headers: { "Accept": "application/json" } })
        .then((r) => r.json())
        .then((data) => {
          const statusNode = card.querySelector("[data-factory-status]")
          const cyclesNode = card.querySelector("[data-factory-cycles]")
          const errorsNode = card.querySelector("[data-factory-errors]")
          const avgNode = card.querySelector("[data-factory-avg]")

          if (statusNode) statusNode.textContent = data.status
          if (cyclesNode) cyclesNode.textContent = data.total_cycles || 0
          if (errorsNode) errorsNode.textContent = data.total_errors || 0
          if (avgNode) avgNode.textContent = data.avg_cycle_duration_ms || 0

          card.dataset.status = data.status
          this.updateStats()
        })
        .catch(() => {})
    })
  }

  updateStats() {
    const selected = this.cardTargets.filter((card) => card.classList.contains("selected")).length
    const playing = this.cardTargets.filter((card) => card.dataset.status === "playing").length

    if (this.hasCountTarget) this.countTarget.textContent = selected
    if (this.hasPlayingTarget) this.playingTarget.textContent = playing
  }
}
