import { Controller } from "@hotwired/stimulus"

// Handles board modals (new board, board settings)
// Accessibility: Escape to close, focus trap, ARIA attributes, restore focus on close
export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this._boundKeydown = this._handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this._boundKeydown)
    this._restoreFocus()
  }

  open(event) {
    if (event) event.preventDefault()
    this._previouslyFocused = document.activeElement
    this.modalTarget.classList.remove("hidden")
    document.addEventListener("keydown", this._boundKeydown)
    // Focus first input after render
    requestAnimationFrame(() => {
      const autofocus = this.modalTarget.querySelector("[autofocus]")
      const firstInput = this.modalTarget.querySelector("input, select, textarea, button:not([data-action*='close'])")
      ;(autofocus || firstInput)?.focus()
    })
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
    document.removeEventListener("keydown", this._boundKeydown)
    this._restoreFocus()
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  // --- Private ---

  _handleKeydown(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.close()
      return
    }

    if (event.key === "Tab") {
      this._trapFocus(event)
    }
  }

  _trapFocus(event) {
    const focusable = Array.from(
      this.modalTarget.querySelectorAll(
        'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
    ).filter(el => el.offsetParent !== null)

    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  _restoreFocus() {
    if (this._previouslyFocused?.focus) {
      this._previouslyFocused.focus()
      this._previouslyFocused = null
    }
  }
}
