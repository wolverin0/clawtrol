import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts
// Implement: / (search), g b (boards), g c (crons), g s (system), ? (help)
export default class extends Controller {
  connect() {
    this._handler = this._handleKeydown.bind(this)
    this._gPressed = false
    document.addEventListener("keydown", this._handler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handler)
  }

  _handleKeydown(event) {
    const tag = event.target.tagName
    if (tag === "INPUT" || tag === "TEXTAREA" || event.target.isContentEditable) {
      return
    }

    const key = event.key.toLowerCase()

    // / -> search
    if (key === "/") {
      event.preventDefault()
      const searchInput = document.querySelector("[data-search-target='input']")
      if (searchInput) {
        searchInput.focus()
      } else {
        // Fallback to command palette
        const cpController = this.application.getControllerForElementAndIdentifier(
          document.querySelector("[data-controller*='command-palette']"),
          "command-palette"
        )
        if (cpController) cpController.open()
      }
      return
    }

    // ? -> help
    if (key === "?") {
      event.preventDefault()
      const kbShortcutsController = this.application.getControllerForElementAndIdentifier(
        document.querySelector("[data-controller*='keyboard-shortcuts']"),
        "keyboard-shortcuts"
      )
      if (kbShortcutsController) kbShortcutsController._toggleHelp()
      return
    }

    // handle 'g' prefix
    if (this._gPressed) {
      this._gPressed = false
      if (key === "b") {
        event.preventDefault()
        window.Turbo.visit("/boards")
      } else if (key === "c") {
        event.preventDefault()
        window.Turbo.visit("/cronjobs")
      } else if (key === "s") {
        event.preventDefault()
        window.Turbo.visit("/system")
      }
      return
    }

    if (key === "g") {
      this._gPressed = true
      // reset after 1s if no second key pressed
      setTimeout(() => { this._gPressed = false }, 1000)
    }
  }
}
