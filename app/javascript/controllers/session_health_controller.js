import { Controller } from "@hotwired/stimulus"

// Manages session health indicator for follow-up task creation
export default class extends Controller {
  static targets = ["indicator", "badge", "warning", "warningText", "checkbox", "sessionKeyField"]
  static values = {
    url: String,
    threshold: { type: Number, default: 70 }
  }

  connect() {
    this.fetchHealth()
  }

  async fetchHealth() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Failed to fetch session health')
      
      const data = await response.json()
      this.updateUI(data)
    } catch (error) {
      console.error('Session health fetch error:', error)
      this.indicatorTarget.textContent = "Unable to check"
      this.indicatorTarget.className = "text-xs font-medium text-content-muted"
    }
  }

  updateUI(data) {
    const { alive, context_percent, recommendation, threshold } = data

    // Update indicator text
    if (!alive) {
      this.indicatorTarget.textContent = "Session ended"
      this.indicatorTarget.className = "text-xs font-medium text-red-400"
    } else {
      this.indicatorTarget.textContent = `${context_percent}% context used`
      
      if (context_percent > threshold) {
        this.indicatorTarget.className = "text-xs font-medium text-yellow-400"
      } else {
        this.indicatorTarget.className = "text-xs font-medium text-green-400"
      }
    }

    // Show/hide badge
    this.badgeTarget.classList.remove("hidden")
    if (!alive) {
      this.badgeTarget.innerHTML = `<span class="px-1.5 py-0.5 rounded text-[10px] font-medium bg-red-500/20 text-red-400">Ended</span>`
    } else if (recommendation === "continue") {
      this.badgeTarget.innerHTML = `<span class="px-1.5 py-0.5 rounded text-[10px] font-medium bg-green-500/20 text-green-400">✅ Good</span>`
    } else {
      this.badgeTarget.innerHTML = `<span class="px-1.5 py-0.5 rounded text-[10px] font-medium bg-yellow-500/20 text-yellow-400">⚠️ High</span>`
    }

    // Show warning if over threshold
    if (alive && context_percent > threshold) {
      this.warningTarget.classList.remove("hidden")
      this.warningTextTarget.textContent = `${context_percent}% used`
    } else if (!alive) {
      this.warningTarget.classList.remove("hidden")
      this.warningTextTarget.textContent = "Session has ended"
    } else {
      this.warningTarget.classList.add("hidden")
    }

    // Store data for checkbox logic
    this.sessionData = data

    // If session is dead or over threshold, uncheck by default
    if (!alive || recommendation !== "continue") {
      this.checkboxTarget.checked = false
      this.sessionKeyFieldTarget.disabled = true
    }
  }

  toggleContinue(event) {
    const checked = event.target.checked
    
    // Enable/disable the session key field
    this.sessionKeyFieldTarget.disabled = !checked

    // Warn if user is overriding recommendation
    if (checked && this.sessionData && this.sessionData.recommendation !== "continue") {
      const confirmed = confirm(
        `Session has ${this.sessionData.context_percent}% context used. ` +
        `Continuing may result in degraded performance. Are you sure?`
      )
      if (!confirmed) {
        event.target.checked = false
        this.sessionKeyFieldTarget.disabled = true
      }
    }
  }
}
