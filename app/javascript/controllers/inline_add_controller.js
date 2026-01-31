import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inline-add"
// Handles Trello-style inline card creation
export default class extends Controller {
  static targets = ["form", "button", "input"]
  static values = {
    status: String,
    url: String
  }

  show() {
    this.buttonTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.buttonTarget.classList.remove("hidden")
    this.inputTarget.value = ""
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit()
    } else if (event.key === "Escape") {
      this.cancel()
    }
  }

  async submit() {
    const title = this.inputTarget.value.trim()
    if (!title) return

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          task: {
            title: title,
            status: this.statusValue
          }
        })
      })

      if (response.ok) {
        // Process turbo stream response to add the card and update counts
        const html = await response.text()
        Turbo.renderStreamMessage(html)

        // Clear input but keep form open for rapid entry
        this.inputTarget.value = ""
        this.inputTarget.focus()
      } else {
        console.error("Failed to create task")
      }
    } catch (error) {
      console.error("Error creating task:", error)
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }
}
