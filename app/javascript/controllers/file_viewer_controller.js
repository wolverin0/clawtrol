import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-viewer"
// Manages the file viewer panel within the task modal.
// Uses fetch-based approach instead of Turbo Frames to avoid issues
// with hidden containers and event.preventDefault() conflicts.
export default class extends Controller {
  static targets = ["panel", "fullscreenModal", "fullscreenContent", "fullscreenFileName"]

  connect() {
    this._handleEscape = this._handleEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleEscape)
  }

  async open(event) {
    event.preventDefault()
    
    const link = event.currentTarget
    const url = link.getAttribute("href")
    
    if (!url) return
    
    // Show the panel immediately
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("hidden")
      
      // Show loading state in the frame
      const frame = this.panelTarget.querySelector("turbo-frame")
      if (frame) {
        frame.innerHTML = `
          <div class="flex items-center justify-center py-12">
            <div class="flex items-center gap-2 text-content-muted">
              <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span class="text-sm">Loading file...</span>
            </div>
          </div>
        `
      }
    }

    try {
      // Fetch the file content via regular HTTP request
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "Turbo-Frame": "file_viewer"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const html = await response.text()
      
      // Parse the response to extract the turbo-frame content
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")
      const responseFrame = doc.querySelector("turbo-frame")
      
      if (this.hasPanelTarget) {
        const frame = this.panelTarget.querySelector("turbo-frame")
        if (frame && responseFrame) {
          frame.innerHTML = responseFrame.innerHTML
        } else if (frame) {
          // Fallback: insert entire response
          frame.innerHTML = html
        }
      }
    } catch (error) {
      console.error("File viewer fetch error:", error)
      if (this.hasPanelTarget) {
        const frame = this.panelTarget.querySelector("turbo-frame")
        if (frame) {
          frame.innerHTML = `
            <div class="flex items-center justify-center py-12">
              <div class="text-center">
                <span class="text-3xl mb-3 block">⚠️</span>
                <p class="text-sm text-red-400">Failed to load file: ${error.message}</p>
              </div>
            </div>
          `
        }
      }
    }
  }

  close() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
      // Clear the content
      const frame = this.panelTarget.querySelector("turbo-frame")
      if (frame) {
        frame.innerHTML = ""
      }
    }
  }

  expand() {
    if (!this.hasFullscreenModalTarget || !this.hasPanelTarget) return

    // Get the file name from the panel header
    const panelFrame = this.panelTarget.querySelector("turbo-frame")
    if (!panelFrame) return

    const fileNameEl = panelFrame.querySelector("[title]")
    const fileName = fileNameEl ? fileNameEl.textContent.trim() : "File"

    // Get the file content (markdown-content div or pre block)
    const contentSource = panelFrame.querySelector(".markdown-content") || panelFrame.querySelector("pre")
    if (!contentSource) return

    // Set the file name in the fullscreen header
    if (this.hasFullscreenFileNameTarget) {
      this.fullscreenFileNameTarget.textContent = fileName
    }

    // Clone the content into the fullscreen modal
    if (this.hasFullscreenContentTarget) {
      const container = this.fullscreenContentTarget.querySelector(".markdown-content")
      if (container) {
        // If source is a markdown-content div, copy its innerHTML
        // If source is a pre block, wrap it appropriately
        if (contentSource.classList.contains("markdown-content")) {
          container.innerHTML = contentSource.innerHTML
        } else {
          container.innerHTML = contentSource.outerHTML
        }
      }
    }

    // Show the fullscreen modal with fade-in
    this.fullscreenModalTarget.classList.remove("hidden")
    // Force reflow then animate
    this.fullscreenModalTarget.offsetHeight
    this.fullscreenModalTarget.style.opacity = "0"
    requestAnimationFrame(() => {
      this.fullscreenModalTarget.style.transition = "opacity 150ms ease-out"
      this.fullscreenModalTarget.style.opacity = "1"
    })

    // Listen for Escape key
    document.addEventListener("keydown", this._handleEscape)
  }

  collapse() {
    if (!this.hasFullscreenModalTarget) return

    // Fade out then hide
    this.fullscreenModalTarget.style.transition = "opacity 150ms ease-in"
    this.fullscreenModalTarget.style.opacity = "0"

    setTimeout(() => {
      this.fullscreenModalTarget.classList.add("hidden")
      this.fullscreenModalTarget.style.opacity = ""
      this.fullscreenModalTarget.style.transition = ""

      // Clear the content
      if (this.hasFullscreenContentTarget) {
        const container = this.fullscreenContentTarget.querySelector(".markdown-content")
        if (container) {
          container.innerHTML = ""
        }
      }
    }, 150)

    document.removeEventListener("keydown", this._handleEscape)
  }

  _handleEscape(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.collapse()
    }
  }
}
