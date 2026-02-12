import { Controller } from "@hotwired/stimulus"

// Controller for AI-enhanced follow-up descriptions
export default class extends Controller {
  static targets = ["textarea", "button", "spinner", "label"]
  static values = { url: String }

  async enhance(event) {
    event.preventDefault()
    
    const draft = this.textareaTarget.value
    if (!draft.trim()) return

    // Show loading state
    this.buttonTarget.disabled = true
    this.spinnerTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Enhancing..."

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ draft: draft })
      })

      if (response.ok) {
        const data = await response.json()
        if (data.enhanced) {
          this.textareaTarget.value = data.enhanced
        }
      }
    } catch (error) {
      console.error("Failed to enhance description:", error)
    } finally {
      // Reset button state
      this.buttonTarget.disabled = false
      this.spinnerTarget.classList.add("hidden")
      this.labelTarget.textContent = "✨ Enhance"
    }
  }
}
