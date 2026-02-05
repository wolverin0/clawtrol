import { Controller } from "@hotwired/stimulus"

// Generic modal controller for closing modals
// Used by followup_modal, new_task_modal, keyboard_help, etc.
// Supports both Turbo frame modals and simple hidden-class modals
export default class extends Controller {
  static targets = ["container"]

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

  open() {
    // For simple hidden-class modals
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("hidden")
    } else {
      this.element.classList.remove("hidden")
    }
  }

  close() {
    // Try Turbo frame approach first (for turbo modals)
    const cancelLink = this.element.querySelector('a[data-turbo-frame="_top"]')
    if (cancelLink) {
      cancelLink.click()
      return
    }

    // For simple hidden-class modals
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("hidden")
    } else {
      this.element.classList.add("hidden")
    }
  }
}
