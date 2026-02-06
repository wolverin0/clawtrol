import { Controller } from "@hotwired/stimulus"

// Controller for validation modal template selection and AI suggestion
export default class extends Controller {
  static targets = ["command", "templates", "aiBtn", "aiSpinner", "aiLabel"]
  static values = { suggestionUrl: String }

  selectTemplate(event) {
    event.preventDefault()
    const command = event.currentTarget.dataset.command
    if (this.hasCommandTarget && command) {
      this.commandTarget.value = command
      this.commandTarget.focus()
    }
  }

  async generateSuggestion(event) {
    event.preventDefault()
    
    if (!this.suggestionUrlValue) {
      console.error("No suggestion URL configured")
      return
    }

    // Show loading state
    if (this.hasAiSpinnerTarget) {
      this.aiSpinnerTarget.classList.remove("hidden")
    }
    if (this.hasAiLabelTarget) {
      this.aiLabelTarget.textContent = "Thinking..."
    }
    if (this.hasAiBtnTarget) {
      this.aiBtnTarget.disabled = true
    }

    try {
      const response = await fetch(this.suggestionUrlValue, {
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
      
      if (this.hasCommandTarget && data.command) {
        this.commandTarget.value = data.command
        this.commandTarget.focus()
      }

      // Update button to show success
      if (this.hasAiLabelTarget) {
        this.aiLabelTarget.textContent = "✓ Applied"
      }
      
      // Reset button after a delay
      setTimeout(() => {
        if (this.hasAiLabelTarget) {
          this.aiLabelTarget.textContent = "AI Suggest"
        }
        if (this.hasAiBtnTarget) {
          this.aiBtnTarget.disabled = false
        }
      }, 2000)

    } catch (error) {
      console.error("Failed to generate suggestion:", error)
      if (this.hasAiLabelTarget) {
        this.aiLabelTarget.textContent = "❌ Failed"
      }
      
      // Reset on error
      setTimeout(() => {
        if (this.hasAiLabelTarget) {
          this.aiLabelTarget.textContent = "AI Suggest"
        }
        if (this.hasAiBtnTarget) {
          this.aiBtnTarget.disabled = false
        }
      }, 2000)
    } finally {
      if (this.hasAiSpinnerTarget) {
        this.aiSpinnerTarget.classList.add("hidden")
      }
    }
  }
}
