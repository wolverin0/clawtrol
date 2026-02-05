import { Controller } from "@hotwired/stimulus"

// Controller for validation modal template selection
export default class extends Controller {
  static targets = ["command", "templates"]

  selectTemplate(event) {
    event.preventDefault()
    const command = event.currentTarget.dataset.command
    if (this.hasCommandTarget && command) {
      this.commandTarget.value = command
      this.commandTarget.focus()
    }
  }
}
