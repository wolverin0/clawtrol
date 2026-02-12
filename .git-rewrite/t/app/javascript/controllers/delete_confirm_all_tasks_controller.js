import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="delete-confirm-all-tasks"
export default class extends Controller {
  static targets = ["modal", "backdrop", "itemName", "form", "description"]
  static values = {
    itemName: String,
    description: String
  }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Close the dropdown manually since we removed it from the data-action
    const dropdownElement = this.element.closest('[data-controller*="dropdown"]')
    if (dropdownElement) {
      const dropdownController = this.application.getControllerForElementAndIdentifier(
        dropdownElement,
        "dropdown"
      )
      if (dropdownController) {
        dropdownController.close()
      }
    }

    // Update the item name in the modal
    this.itemNameTarget.textContent = this.itemNameValue
    
    // Update description if provided
    if (this.hasDescriptionTarget && this.hasDescriptionValue) {
      this.descriptionTarget.textContent = this.descriptionValue
    }

    // Show modal and backdrop
    this.modalTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")

    // Trigger animation
    requestAnimationFrame(() => {
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
      this.modalTarget.classList.remove("opacity-0", "scale-95")
      this.modalTarget.classList.add("opacity-100", "scale-100")
    })

    // Add keyboard listener
    document.addEventListener("keydown", this.handleKeydown)

    // Focus the cancel button for accessibility
    const cancelButton = this.modalTarget.querySelector('[data-action*="close"]')
    if (cancelButton) {
      setTimeout(() => cancelButton.focus(), 100)
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    // Fade out
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    this.modalTarget.classList.remove("opacity-100", "scale-100")
    this.modalTarget.classList.add("opacity-0", "scale-95")

    // Hide after animation
    setTimeout(() => {
      this.modalTarget.classList.add("hidden")
      this.backdropTarget.classList.add("hidden")
    }, 200)

    // Remove keyboard listener
    document.removeEventListener("keydown", this.handleKeydown)
  }

  closeOnBackdrop(event) {
    // Only close if clicking the backdrop itself, not its children
    if (event.target === event.currentTarget) {
      this.close(event)
    }
  }

  confirm(event) {
    event.preventDefault()
    event.stopPropagation()

    // Remove keyboard listener
    document.removeEventListener("keydown", this.handleKeydown)

    // Close the modal
    this.close()

    // Submit the form - Turbo will handle it
    this.formTarget.requestSubmit()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
