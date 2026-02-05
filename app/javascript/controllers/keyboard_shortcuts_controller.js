import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts for power users
// Attach to <body> with data-controller="keyboard-shortcuts"
export default class extends Controller {
  connect() {
    this._handler = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this._handler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handler)
  }

  _handleKeydown(event) {
    // Ignore when typing in input, textarea, or contenteditable
    const tag = event.target.tagName
    if (tag === "INPUT" || tag === "TEXTAREA" || event.target.isContentEditable) {
      // Exception: Escape should still work to close modals
      if (event.key === "Escape") {
        this._closeHelp()
      }
      return
    }

    // Escape → close help modal (and other modals already handled elsewhere)
    if (event.key === "Escape") {
      event.preventDefault()
      this._closeHelp()
      return
    }

    // ? → show help
    if (event.key === "?" && !event.ctrlKey && !event.metaKey) {
      event.preventDefault()
      this._toggleHelp()
      return
    }

    // n → new task (focus add card input in first column)
    if (event.key === "n" && !event.ctrlKey && !event.metaKey) {
      event.preventDefault()
      const addInput = document.querySelector("[data-new-task-target='input']") ||
                       document.querySelector("[data-add-task-target='input']") ||
                       document.querySelector("input[placeholder*='Add a card']") ||
                       document.querySelector("input[placeholder*='Add a task']")
      if (addInput) {
        addInput.focus()
        addInput.scrollIntoView({ behavior: "smooth", block: "center" })
      }
      return
    }

    // Ctrl+/ or Cmd+/ → toggle terminal
    if (event.key === "/" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault()
      this._toggleTerminal()
      return
    }
  }

  _toggleHelp() {
    const modal = document.getElementById("keyboard-shortcuts-help")
    if (modal) {
      modal.classList.toggle("hidden")
      // Focus trap: focus the modal when shown
      if (!modal.classList.contains("hidden")) {
        modal.focus()
      }
    }
  }

  _closeHelp() {
    const modal = document.getElementById("keyboard-shortcuts-help")
    if (modal && !modal.classList.contains("hidden")) {
      modal.classList.add("hidden")
    }
  }

  _toggleTerminal() {
    // Try to find and trigger the agent terminal controller
    const terminalController = this.application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller*='agent-terminal']"),
      "agent-terminal"
    )
    if (terminalController && typeof terminalController.toggle === "function") {
      terminalController.toggle()
      return
    }

    // Fallback: click the toggle button
    const toggleBtn = document.querySelector("[data-action*='agent-terminal#toggle']")
    if (toggleBtn) {
      toggleBtn.click()
    }
  }
}
