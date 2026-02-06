import { Controller } from "@hotwired/stimulus"

/**
 * Mobile Filter Controller
 * Handles expanding/collapsing filters on mobile devices
 */
export default class extends Controller {
  static targets = ["toggle", "panel", "chevron"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    this.isOpen = !this.isOpen
    
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden", !this.isOpen)
    }
    
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-180", this.isOpen)
    }
  }
}
