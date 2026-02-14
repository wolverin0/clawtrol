import { Controller } from "@hotwired/stimulus"

/**
 * Flash message controller — auto-dismiss + screen reader announcement.
 *
 * Usage:
 *   <div data-controller="flash"
 *        data-flash-type-value="notice"
 *        role="alert">
 *     Your message here
 *   </div>
 */
export default class extends Controller {
  static values = {
    type: { type: String, default: "notice" },  // "notice", "alert", "error"
    duration: { type: Number, default: 3000 }
  }

  connect() {
    // Announce to screen readers via live region
    const message = this.element.textContent.trim()
    if (message) {
      const priority = this.typeValue === "error" || this.typeValue === "alert"
        ? "assertive"
        : "polite"
      window.dispatchEvent(new CustomEvent("announce", {
        detail: { message, priority }
      }))
    }

    // Auto-dismiss after configured duration
    this._timeout = setTimeout(() => {
      this.dismiss()
    }, this.durationValue)
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  dismiss() {
    this.element.classList.add("opacity-0")
    this.element.style.transition = "opacity 500ms ease-out"

    setTimeout(() => {
      this.element.remove()
    }, 500)
  }
}
