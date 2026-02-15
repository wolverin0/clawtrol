import { Controller } from "@hotwired/stimulus"

// Tiny controller: sync a range input's value to a display element.
export default class extends Controller {
  static targets = ["range", "display"]

  update() {
    if (this.hasRangeTarget && this.hasDisplayTarget) {
      this.displayTarget.textContent = `${this.rangeTarget.value}ms`
    }
  }

  updatePct() {
    if (this.hasRangeTarget && this.hasDisplayTarget) {
      this.displayTarget.textContent = `${Math.round(this.rangeTarget.value * 100)}%`
    }
  }
}
