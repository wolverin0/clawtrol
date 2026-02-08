import { Controller } from "@hotwired/stimulus"

// Simple dropdown/panel toggle for the OpenClaw memory health badge.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this._onClickOutside = this.onClickOutside.bind(this)
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()

    if (this.panelTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    document.addEventListener("click", this._onClickOutside)
  }

  close() {
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.add("hidden")
    document.removeEventListener("click", this._onClickOutside)
  }

  onClickOutside(event) {
    if (this.element.contains(event.target)) return
    this.close()
  }
}
