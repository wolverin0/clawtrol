import { Controller } from "@hotwired/stimulus"

// EvidenceTabsController
// Minimal tab switcher for Task panel Evidence: Transcript / Artifacts / Events
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: String, default: "transcript" } }

  connect() {
    this.show(this.activeValue)
  }

  select(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.key
    if (key) this.show(key)
  }

  show(key) {
    this.activeValue = key

    this.tabTargets.forEach((t) => {
      const active = t.dataset.key === key
      t.classList.toggle("bg-bg-elevated", !active)
      t.classList.toggle("bg-accent/20", active)
      t.classList.toggle("text-content-muted", !active)
      t.classList.toggle("text-accent", active)
    })

    this.panelTargets.forEach((p) => {
      p.classList.toggle("hidden", p.dataset.key !== key)
    })
  }
}
