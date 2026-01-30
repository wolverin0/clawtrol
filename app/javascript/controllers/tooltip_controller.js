import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = {
    delay: { type: Number, default: 400 },
    text: String
  }

  connect() {
    this.timeout = null
    this.tooltipEl = null
  }

  disconnect() {
    this.hide()
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  show() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.timeout = setTimeout(() => {
      this.createTooltip()
    }, this.delayValue)
  }

  hide() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }

    if (this.tooltipEl) {
      this.tooltipEl.remove()
      this.tooltipEl = null
    }
  }

  createTooltip() {
    if (this.tooltipEl) return

    const rect = this.element.getBoundingClientRect()
    const text = this.textValue || this.element.dataset.tooltipText || ""

    if (!text) return

    this.tooltipEl = document.createElement("div")
    this.tooltipEl.className = "fixed px-2.5 py-1.5 text-xs font-medium text-white bg-stone-900 rounded-lg shadow-lg whitespace-nowrap z-[9999] transition-opacity duration-150"
    this.tooltipEl.textContent = text
    this.tooltipEl.style.opacity = "0"

    document.body.appendChild(this.tooltipEl)

    // Position tooltip to the right of the element
    const tooltipRect = this.tooltipEl.getBoundingClientRect()
    const top = rect.top + (rect.height / 2) - (tooltipRect.height / 2)
    const left = rect.right + 8

    this.tooltipEl.style.top = `${top}px`
    this.tooltipEl.style.left = `${left}px`

    // Fade in
    requestAnimationFrame(() => {
      if (this.tooltipEl) {
        this.tooltipEl.style.opacity = "1"
      }
    })
  }
}
