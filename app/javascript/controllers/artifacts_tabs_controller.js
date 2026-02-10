import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="artifacts-tabs"
// Simple tab switcher for Files/Changes sub-tabs within artifacts panel
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Activate first tab by default
    this.select({ currentTarget: this.tabTargets[0] })
  }

  select(event) {
    const selectedKey = event.currentTarget.dataset.key

    // Update tab styles
    this.tabTargets.forEach(tab => {
      if (tab.dataset.key === selectedKey) {
        tab.classList.remove("bg-bg-elevated", "text-content-muted")
        tab.classList.add("bg-accent/20", "text-accent")
      } else {
        tab.classList.remove("bg-accent/20", "text-accent")
        tab.classList.add("bg-bg-elevated", "text-content-muted")
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.key === selectedKey) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
