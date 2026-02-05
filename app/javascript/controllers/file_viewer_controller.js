import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-viewer"
// Manages the file viewer panel within the task modal.
// Uses fetch-based approach instead of Turbo Frames to avoid issues
// with hidden containers and event.preventDefault() conflicts.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    // Nothing needed on connect
  }

  disconnect() {
    // Nothing needed on disconnect
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
}
