import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["generateBtn", "spinner", "label", "textarea"]
  static values = { url: String, cached: Boolean }

  connect() {
    // Don't auto-generate - wait for user to click the button
  }

  async generate() {
    if (!this.urlValue) return

    // Show loading state
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = "Generating..."
    }
    if (this.hasGenerateBtnTarget) {
      this.generateBtnTarget.disabled = true
    }

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      
      if (!response.ok) {
        throw new Error('Failed to generate suggestion')
      }

      const data = await response.json()
      
      if (this.hasTextareaTarget && data.suggested_followup) {
        this.textareaTarget.value = data.suggested_followup
      }

      // Hide the button after successful generation
      if (this.hasGenerateBtnTarget) {
        this.generateBtnTarget.classList.add("hidden")
      }
    } catch (error) {
      console.error("Failed to generate suggestion:", error)
      if (this.hasLabelTarget) {
        this.labelTarget.textContent = "❌ Failed - try again"
      }
      if (this.hasGenerateBtnTarget) {
        this.generateBtnTarget.disabled = false
      }
    } finally {
      if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.add("hidden")
      }
    }
  }
}
