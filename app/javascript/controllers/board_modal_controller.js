import { Controller } from "@hotwired/stimulus"

// Handles board modals (new board, board settings)
export default class extends Controller {
  static targets = ["modal"]
  
  open(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
  }
  
  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
  }
  
  closeOnBackdrop(event) {
    // Only close if clicking directly on the backdrop
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}
