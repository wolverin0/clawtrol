import { Controller } from "@hotwired/stimulus"

// Adds long-press (touch) support for context menus on mobile
// Works alongside the dropdown controller to trigger openAtCursor on touch devices
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 500 }
  }

  connect() {
    this.pressTimer = null
    this.touchStartX = 0
    this.touchStartY = 0

    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchEnd = this.onTouchEnd.bind(this)
    this.onTouchMove = this.onTouchMove.bind(this)

    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchend", this.onTouchEnd)
    this.element.addEventListener("touchmove", this.onTouchMove)
  }

  disconnect() {
    this.clearTimer()
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchend", this.onTouchEnd)
    this.element.removeEventListener("touchmove", this.onTouchMove)
  }

  onTouchStart(event) {
    const touch = event.touches[0]
    this.touchStartX = touch.clientX
    this.touchStartY = touch.clientY

    this.clearTimer()
    this.pressTimer = setTimeout(() => {
      // Simulate a contextmenu event at the touch position
      const contextEvent = new MouseEvent("contextmenu", {
        bubbles: true,
        cancelable: true,
        clientX: this.touchStartX,
        clientY: this.touchStartY
      })
      this.element.dispatchEvent(contextEvent)
    }, this.delayValue)
  }

  onTouchEnd(event) {
    this.clearTimer()
  }

  onTouchMove(event) {
    // Cancel long-press if finger moves more than 10px
    if (this.pressTimer) {
      const touch = event.touches[0]
      const dx = Math.abs(touch.clientX - this.touchStartX)
      const dy = Math.abs(touch.clientY - this.touchStartY)
      if (dx > 10 || dy > 10) {
        this.clearTimer()
      }
    }
  }

  clearTimer() {
    if (this.pressTimer) {
      clearTimeout(this.pressTimer)
      this.pressTimer = null
    }
  }
}
