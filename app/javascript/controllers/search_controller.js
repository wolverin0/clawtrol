import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
// Header search bar with keyboard shortcuts and live search
export default class extends Controller {
  static targets = ["input", "container", "results"]
  static values = {
    url: { type: String, default: "/search" },
    debounceMs: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimer = null
    this.isOpen = false
    this.setupKeyboardShortcuts()
  }

  disconnect() {
    this.removeKeyboardShortcuts()
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  setupKeyboardShortcuts() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  removeKeyboardShortcuts() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    // "/" to focus search (when not in an input)
    if (event.key === "/" && !this.isInputFocused()) {
      event.preventDefault()
      this.open()
      return
    }

    // "Escape" to close/blur
    if (event.key === "Escape" && this.hasInputTarget && document.activeElement === this.inputTarget) {
      event.preventDefault()
      this.close()
      return
    }

    // Cmd/Ctrl + K as alternative
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      this.toggle()
    }
  }

  isInputFocused() {
    const active = document.activeElement
    if (!active) return false
    const tagName = active.tagName.toLowerCase()
    return tagName === "input" || tagName === "textarea" || active.isContentEditable
  }

  open() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("hidden")
    }
    if (this.hasInputTarget) {
      this.inputTarget.focus()
      this.inputTarget.select()
    }
    this.isOpen = true
  }

  close() {
    if (this.hasInputTarget) {
      this.inputTarget.blur()
    }
    if (this.hasContainerTarget && this.hasInputTarget && !this.inputTarget.value.trim()) {
      this.containerTarget.classList.add("hidden")
    }
    this.isOpen = false
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  // Live search with debounce
  search(event) {
    const query = event.target.value.trim()

    if (this.debounceTimer) clearTimeout(this.debounceTimer)

    if (query.length < 2) {
      if (this.hasResultsTarget) {
        this.resultsTarget.innerHTML = ""
      }
      return
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceMs)
  }

  async performSearch(query) {
    if (!this.hasResultsTarget) return

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)

      const response = await fetch(url, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        // For turbo-stream response
        if (response.headers.get("content-type")?.includes("turbo-stream")) {
          Turbo.renderStreamMessage(html)
        } else {
          // For HTML fragment response (if we add a partial endpoint)
          this.resultsTarget.innerHTML = html
        }
      }
    } catch (error) {
      console.error("Search failed:", error)
    }
  }

  // Submit form on Enter
  submit(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      const query = this.inputTarget.value.trim()
      if (query) {
        window.location.href = `${this.urlValue}?q=${encodeURIComponent(query)}`
      }
    }
  }
}
