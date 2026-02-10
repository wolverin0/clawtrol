import { Controller } from "@hotwired/stimulus"

// Collapsible tree node controller
export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.updateState()
  }

  toggle() {
    this.openValue = !this.openValue
    this.updateState()
  }

  updateState() {
    if (this.hasContentTarget) {
      if (this.openValue) {
        this.contentTarget.classList.remove("hidden")
      } else {
        this.contentTarget.classList.add("hidden")
      }
    }

    if (this.hasIconTarget) {
      this.iconTarget.style.transform = this.openValue ? "rotate(90deg)" : "rotate(0deg)"
    }
  }
}
