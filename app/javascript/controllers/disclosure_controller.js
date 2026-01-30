import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "label"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    this.updateUI()
  }

  toggle() {
    this.openValue = !this.openValue
    this.updateUI()
  }

  updateUI() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.openValue)
    }
    if (this.hasIconTarget) {
      this.iconTarget.style.transform = this.openValue ? "rotate(180deg)" : "rotate(0deg)"
    }
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.openValue ? "Hide instructions" : "Show instructions"
    }
  }
}
