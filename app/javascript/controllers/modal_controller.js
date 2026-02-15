import { Controller } from "@hotwired/stimulus"
import { FocusTrap } from "helpers/focus_trap"

// Generic modal controller for closing modals
// Used by followup_modal, new_task_modal, keyboard_help, etc.
// Supports both Turbo frame modals and simple hidden-class modals
// Accessibility: focus trap (Tab/Shift+Tab), Escape to close, restores focus on close
export default class extends Controller {
  static targets = ["container"]

  connect() {
    const el = this.hasContainerTarget ? this.containerTarget : this.element
    this.focusTrap = new FocusTrap(el, { onEscape: () => this.close() })
  }

  disconnect() {
    this.focusTrap?.deactivate()
  }

  open() {
    const el = this.hasContainerTarget ? this.containerTarget : this.element
    el.classList.remove("hidden")
    el.setAttribute("role", "dialog")
    el.setAttribute("aria-modal", "true")
    this.focusTrap.activate()
  }

  close() {
    this.focusTrap.deactivate()

    // Try Turbo frame approach first (for turbo modals)
    const cancelLink = this.element.querySelector('a[data-turbo-frame="_top"]')
    if (cancelLink) {
      cancelLink.click()
      return
    }

    // For simple hidden-class modals
    const el = this.hasContainerTarget ? this.containerTarget : this.element
    el.classList.add("hidden")
    el.removeAttribute("aria-modal")
  }
}
