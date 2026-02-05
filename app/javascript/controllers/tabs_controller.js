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

  // Legacy action name for backwards compatibility
  select(event) {
    event.preventDefault()
    this.selectTab(event.currentTarget)
  }

  // New action name matching task spec
  switch(event) {
    event.preventDefault()
    this.selectTab(event.currentTarget)
  }

  selectTab(selectedTab) {
    // Support both data-tab-id (legacy) and data-tab (new)
    const selectedId = selectedTab.dataset.tab || selectedTab.dataset.tabId

    // Update tab styles
    this.tabTargets.forEach(tab => {
      const tabId = tab.dataset.tab || tab.dataset.tabId
      const isActive = tabId === selectedId
      
      // Active state
      tab.classList.toggle("border-accent", isActive)
      tab.classList.toggle("text-content", isActive)
      
      // Inactive state
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-content-muted", !isActive)
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      const panelId = panel.dataset.tab || panel.dataset.tabId
      panel.classList.toggle("hidden", panelId !== selectedId)
    })
  }
}
