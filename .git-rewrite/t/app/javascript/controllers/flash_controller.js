import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  connect() {
    // Auto-dismiss after 3 seconds
    setTimeout(() => {
      this.dismiss()
    }, 3000)
  }

  dismiss() {
    // Add fade-out animation
    this.element.classList.add("opacity-0", "transition-opacity", "duration-500")

    // Remove element from DOM after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }
}
