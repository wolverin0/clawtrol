import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["details"]

  toggle() {
    if (!this.hasDetailsTarget) return
    this.detailsTarget.classList.toggle("hidden")
  }
}
