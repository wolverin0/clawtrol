import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: { type: Number, default: 60000 } }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  refresh() {
    // Use Turbo to reload the frame
    if (this.element.tagName === "TURBO-FRAME") {
      this.element.reload()
    } else {
      // Fallback: fetch and replace
      fetch(window.location.href, { headers: { "Turbo-Frame": this.element.id } })
        .then(r => r.text())
        .then(html => {
          const parser = new DOMParser()
          const doc = parser.parseFromString(html, "text/html")
          const frame = doc.querySelector(`#${this.element.id}`)
          if (frame) this.element.innerHTML = frame.innerHTML
        })
        .catch(() => {})
    }
  }
}
