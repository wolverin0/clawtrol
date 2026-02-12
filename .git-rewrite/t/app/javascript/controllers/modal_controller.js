import { Controller } from "@hotwired/stimulus"

// Generic modal controller for closing modals
// Used by followup_modal, new_task_modal, etc.
export default class extends Controller {
  connect() {
    // Listen for ESC key globally
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  close() {
    // Navigate to board path to clear the turbo frame
    const cancelLink = this.element.querySelector('a[data-turbo-frame="_top"]')
    if (cancelLink) {
      cancelLink.click()
    }
  }
}
