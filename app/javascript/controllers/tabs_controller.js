import { Controller } from "@hotwired/stimulus"

// Controller for tabbed interfaces
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Ensure first tab is selected on connect
    if (this.tabTargets.length > 0) {
      this.selectTab(this.tabTargets[0])
    }
  }

  select(event) {
    event.preventDefault()
    this.selectTab(event.currentTarget)
  }

  selectTab(selectedTab) {
    const selectedId = selectedTab.dataset.tabId

    // Update tab styles
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tabId === selectedId) {
        tab.classList.remove("border-transparent", "text-content-muted")
        tab.classList.add("border-accent", "text-accent")
      } else {
        tab.classList.remove("border-accent", "text-accent")
        tab.classList.add("border-transparent", "text-content-muted")
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.tabId === selectedId) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
