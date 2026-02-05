import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-viewer"
// Manages the file viewer panel within the task modal.
// Uses fetch-based approach instead of Turbo Frames to avoid issues
// with hidden containers and event.preventDefault() conflicts.
export default class extends Controller {
  static targets = ["panel", "fullscreenModal", "fullscreenContent", "fullscreenFileName"]

  connect() {
    this._handleEscape = this._handleEscape.bind(this)
    
    // Save original parent for moving fullscreen modal back after collapse
    // Store direct reference since Stimulus targets may disconnect when moved
    if (this.hasFullscreenModalTarget) {
      this._originalParent = this.fullscreenModalTarget.parentElement
      this._fullscreenModal = this.fullscreenModalTarget
    }
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
    // Use stored reference since target disconnects when moved out of controller scope
    const modal = this._fullscreenModal
    if (!modal || !this.hasPanelTarget) return

    // Get the file name from the panel header
    const panelFrame = this.panelTarget.querySelector("turbo-frame")
    if (!panelFrame) return

    const fileNameEl = panelFrame.querySelector("[title]")
    const fileName = fileNameEl ? fileNameEl.textContent.trim() : "File"

    // Get the file content (markdown-content div or pre block)
    const contentSource = panelFrame.querySelector(".markdown-content") || panelFrame.querySelector("pre")
    if (!contentSource) return

    // Set the file name
    const fileNameTarget = modal.querySelector("[data-file-viewer-target='fullscreenFileName']")
    if (fileNameTarget) {
      fileNameTarget.textContent = fileName
    }

    // Clone the content
    const contentTarget = modal.querySelector("[data-file-viewer-target='fullscreenContent']")
    if (contentTarget) {
      const container = contentTarget.querySelector(".markdown-content")
      if (container) {
        if (contentSource.classList.contains("markdown-content")) {
          container.innerHTML = contentSource.innerHTML
        } else {
          container.innerHTML = contentSource.outerHTML
        }
      }
    }

    // Move modal to body to escape transform containing block
    document.body.appendChild(modal)

    // Lock body scroll so the page doesn't scroll behind the modal
    document.body.style.overflow = "hidden"

    // Show the fullscreen modal
    modal.classList.remove("hidden")
    modal.offsetHeight // force reflow
    modal.style.opacity = "0"
    requestAnimationFrame(() => {
      modal.style.transition = "opacity 150ms ease-out"
      modal.style.opacity = "1"
    })

    // Listen for Escape key
    document.addEventListener("keydown", this._handleEscape)
  }

  collapse() {
    const modal = this._fullscreenModal
    if (!modal) return

    // Restore body scroll
    document.body.style.overflow = ""

    // Fade out then hide
    modal.style.transition = "opacity 150ms ease-in"
    modal.style.opacity = "0"

    setTimeout(() => {
      modal.classList.add("hidden")
      modal.style.opacity = ""
      modal.style.transition = ""

      // Clear the content
      const container = modal.querySelector("[data-file-viewer-target='fullscreenContent']")
      if (container) {
        const markdownDiv = container.querySelector(".markdown-content")
        if (markdownDiv) {
          markdownDiv.innerHTML = ""
        }
      }

      // Move modal back to original parent for Stimulus targets
      if (this._originalParent) {
        this._originalParent.appendChild(modal)
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
