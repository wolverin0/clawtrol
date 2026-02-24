import { Controller } from "@hotwired/stimulus"

// Task modal tab switching controller
// Manages the right-side tabbed panel in the two-column task modal
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: String, default: "summary" } }

  connect() {
    this.showTab(this.activeValue)
  }

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    if (tabName) {
      this.activeValue = tabName
      this.showTab(tabName)
    }
  }

  showTab(name) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === name
      tab.classList.toggle("border-accent", isActive)
      tab.classList.toggle("text-content", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-content-muted", !isActive)
    })

    // Update panels
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.tab === name
      panel.classList.toggle("hidden", !isActive)
    })
  }
}
