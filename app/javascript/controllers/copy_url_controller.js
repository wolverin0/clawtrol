import { Controller } from "@hotwired/stimulus"

// Handles copying task URLs to clipboard
export default class extends Controller {
  static values = { url: String }
  
  copy(event) {
    event.preventDefault()
    const button = event.currentTarget
    const url = this.urlValue || this.buildUrl()
    
    navigator.clipboard.writeText(url).then(() => {
      // Visual feedback
      const originalContent = button.innerHTML
      button.innerHTML = "✅"
      setTimeout(() => {
        button.innerHTML = originalContent
      }, 1500)
    }).catch(err => {
      console.error("Failed to copy URL:", err)
    })
  }
  
  buildUrl() {
    return window.location.origin + window.location.pathname
  }
}
