import { Controller } from "@hotwired/stimulus"

// Handles icon selection in board create/edit forms
export default class extends Controller {
  static targets = ["button", "field"]
  
  select(event) {
    event.preventDefault()
    const button = event.currentTarget
    const icon = button.dataset.icon
    
    // Update hidden field
    this.fieldTarget.value = icon
    
    // Update visual state - remove ring from all buttons
    this.buttonTargets.forEach(btn => {
      btn.classList.remove("ring-2", "ring-accent")
    })
    
    // Add ring to selected button
    button.classList.add("ring-2", "ring-accent")
  }
}
