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
    this.longPressTriggered = false
    this.suppressNextClick = false

    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchEnd = this.onTouchEnd.bind(this)
    this.onTouchMove = this.onTouchMove.bind(this)
    this.onTouchCancel = this.onTouchCancel.bind(this)
    this.onClickCapture = this.onClickCapture.bind(this)

    // Capture phase so long-press still works inside nested headers/modals.
    // Keep touchstart non-passive so we can prevent default behaviors after long-press.
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: false, capture: true })
    this.element.addEventListener("touchend", this.onTouchEnd, { capture: true })
    this.element.addEventListener("touchmove", this.onTouchMove, { capture: true })
    this.element.addEventListener("touchcancel", this.onTouchCancel, { capture: true })
    this.element.addEventListener("click", this.onClickCapture, true)
  }

  disconnect() {
    this.clearTimer()
    this.element.removeEventListener("touchstart", this.onTouchStart, { capture: true })
    this.element.removeEventListener("touchend", this.onTouchEnd, { capture: true })
    this.element.removeEventListener("touchmove", this.onTouchMove, { capture: true })
    this.element.removeEventListener("touchcancel", this.onTouchCancel, { capture: true })
    this.element.removeEventListener("click", this.onClickCapture, true)
  }

  onTouchStart(event) {
    const touch = event.touches[0]
    this.touchStartX = touch.clientX
    this.touchStartY = touch.clientY
    this.longPressTriggered = false

    this.clearTimer()
    this.pressTimer = setTimeout(() => {
      this.longPressTriggered = true
      this.suppressNextClick = true

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

    // After long-press, block the synthetic click so modal doesn't open/flicker
    if (this.longPressTriggered) {
      event.preventDefault()
    }
  }

  onTouchCancel() {
    this.clearTimer()
    this.longPressTriggered = false
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

  onClickCapture(event) {
    if (!this.suppressNextClick) return

    event.preventDefault()
    event.stopPropagation()
    this.suppressNextClick = false
    this.longPressTriggered = false
  }

  clearTimer() {
    if (this.pressTimer) {
      clearTimeout(this.pressTimer)
      this.pressTimer = null
    }
  }
}
