import { Controller } from "@hotwired/stimulus"

/**
 * LiveRegionController — ARIA live region announcer for screen readers.
 *
 * Place a single instance in the layout:
 *   <div data-controller="live-region"
 *        data-live-region-target="polite"
 *        aria-live="polite" aria-atomic="true"
 *        class="sr-only"></div>
 *   <div data-live-region-target="assertive"
 *        aria-live="assertive" aria-atomic="true"
 *        class="sr-only"></div>
 *
 * Announce from anywhere via custom events:
 *   window.dispatchEvent(new CustomEvent("announce", {
 *     detail: { message: "Task moved to In Review", priority: "polite" }
 *   }))
 *
 * Or use the static helper:
 *   LiveRegionController.announce("Task created", "assertive")
 */
export default class extends Controller {
  static targets = ["polite", "assertive"]

  connect() {
    this._handleAnnounce = this._handleAnnounce.bind(this)
    window.addEventListener("announce", this._handleAnnounce)
  }

  disconnect() {
    window.removeEventListener("announce", this._handleAnnounce)
  }

  _handleAnnounce(event) {
    const { message, priority = "polite" } = event.detail || {}
    if (!message) return

    const target = priority === "assertive"
      ? this.assertiveTarget
      : this.politeTarget

    // Clear then set to ensure screen readers re-announce
    target.textContent = ""
    requestAnimationFrame(() => {
      target.textContent = message
    })

    // Auto-clear after 5 seconds
    setTimeout(() => {
      target.textContent = ""
    }, 5000)
  }

  /**
   * Static helper for announcing from non-Stimulus code.
   * @param {string} message
   * @param {"polite"|"assertive"} priority
   */
  static announce(message, priority = "polite") {
    window.dispatchEvent(new CustomEvent("announce", {
      detail: { message, priority }
    }))
  }
}
