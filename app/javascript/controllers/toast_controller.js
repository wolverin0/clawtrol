import { Controller } from "@hotwired/stimulus"

// Auto-dismissing toast notifications
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 5000 }
  }

  connect() {
    // Add pointer-events to make toast clickable
    this.element.classList.add('pointer-events-auto')
    
    // Start auto-dismiss timer
    this.dismissTimer = setTimeout(() => this.dismiss(), this.durationValue)
    
    // Add slide-in animation class
    this.element.classList.add('animate-slide-in')
  }

  disconnect() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }
  }

  dismiss() {
    // Add slide-out animation
    this.element.classList.remove('animate-slide-in')
    this.element.classList.add('animate-slide-out')
    
    // Remove after animation
    setTimeout(() => {
      this.element.remove()
    }, 200)
  }
}
