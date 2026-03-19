import { Controller } from "@hotwired/stimulus"

// Auto-dismiss toast notifications after a delay
export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.remove("animate-slide-in")
    this.element.classList.add("animate-slide-out")
    setTimeout(() => this.element.remove(), 200)
  }
}
