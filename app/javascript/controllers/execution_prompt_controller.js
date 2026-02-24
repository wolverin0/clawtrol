import { Controller } from "@hotwired/stimulus"

// Execution prompt editor controller
// Allows editing execution_prompt before first run, locks after
export default class extends Controller {
  static targets = ["display", "editor", "input"]
  static values = { url: String, locked: Boolean }

  enable() {
    if (this.lockedValue) return
    this.displayTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  cancel() {
    this.editorTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }

  async save() {
    const value = this.inputTarget.value
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ task: { execution_prompt: value } })
      })
      if (response.ok) {
        this.displayTarget.textContent = value || "(empty)"
        this.cancel()
      }
    } catch (e) {
      console.error("Failed to save execution prompt:", e)
    }
  }
}
