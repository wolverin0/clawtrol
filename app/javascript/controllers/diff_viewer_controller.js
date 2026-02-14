import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="diff-viewer"
// Enhanced diff viewer using diff2html.js for GitHub-style rendering
// Supports unified/side-by-side toggle, collapsible files, syntax highlighting
export default class extends Controller {
  static targets = [
    "container",
    "diffPanel",
    "diffContent",
    "fileName",
    "stats",
    "fullscreenModal",
    "fullscreenContent",
    "fullscreenFileName",
    "fullscreenStats",
    "viewToggle",
    "summaryBar"
  ]

  static values = {
    taskId: Number,
    outputType: { type: String, default: "line-by-line" } // "line-by-line" or "side-by-side"
  }

  connect() {
    this._handleEscape = this._handleEscape.bind(this)
    this._currentDiffString = null
    this._currentFilePath = null
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleEscape)
  }

  // Load diff for a specific file via fetch
  async loadDiff(event) {
    event.preventDefault()

    const button = event.currentTarget
    const filePath = button.dataset.filePath
    const diffUrl = button.dataset.diffUrl

    if (!diffUrl) return

    this._currentFilePath = filePath

    // Show loading state
    if (this.hasDiffPanelTarget) {
      this.diffPanelTarget.classList.remove("hidden")
      this.diffContentTarget.innerHTML = this._loadingHtml()
    }

    try {
      // Fetch raw diff content as JSON
      const response = await fetch(diffUrl + (diffUrl.includes("?") ? "&" : "?") + "format=json", {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()
      this._currentDiffString = data.diff_content

      if (this.hasFileNameTarget) {
        this.fileNameTarget.textContent = filePath
      }

      this._renderDiff()
    } catch (error) {
      console.error("Diff viewer fetch error:", error)
      // Fallback: try HTML fetch (backward compatible)
      await this._loadDiffHtmlFallback(diffUrl, filePath)
    }
  }

  // Render diff from a data attribute (inline diff)
  renderInline(event) {
    const el = event?.currentTarget || this.element
    const diffString = el.dataset.diffContent || el.dataset.diffViewerDiffContent
    if (!diffString) return

    this._currentDiffString = diffString
    this._currentFilePath = el.dataset.filePath || "diff"
    this._renderDiff()
  }

  // Toggle between unified and side-by-side
  toggleView(event) {
    const mode = event.currentTarget.dataset.viewMode
    if (!mode) return

    this.outputTypeValue = mode
    
    // Update active button state
    this.viewToggleTargets.forEach(btn => {
      btn.classList.toggle("active", btn.dataset.viewMode === mode)
    })

    if (this._currentDiffString) {
      this._renderDiff()
    }
  }

  // Collapse/expand a file section
  toggleFileCollapse(event) {
    const header = event.currentTarget.closest(".d2h-file-header")
    if (!header) return

    const wrapper = header.closest(".d2h-file-wrapper")
    if (!wrapper) return

    wrapper.classList.toggle("collapsed")
    
    const icon = header.querySelector(".collapse-icon")
    if (icon) {
      icon.textContent = wrapper.classList.contains("collapsed") ? "▶" : "▼"
    }
  }

  // Also handle the old-style collapsed sections
  toggleCollapsed(event) {
    const button = event.currentTarget
    const section = button.closest("[data-collapsed-section]")
    if (!section) return

    const content = section.querySelector("[data-collapsed-content]")
    const icon = button.querySelector("[data-collapse-icon]")
    
    if (content.classList.contains("hidden")) {
      content.classList.remove("hidden")
      if (icon) icon.textContent = "▼"
      button.setAttribute("aria-expanded", "true")
    } else {
      content.classList.add("hidden")
      if (icon) icon.textContent = "▶"
      button.setAttribute("aria-expanded", "false")
    }
  }

  close() {
    if (this.hasDiffPanelTarget) {
      this.diffPanelTarget.classList.add("hidden")
      this.diffContentTarget.innerHTML = ""
    }
    this._currentDiffString = null
    this._currentFilePath = null
  }

  expand() {
    const modal = this.fullscreenModalTarget
    if (!modal) return

    const fileName = this._currentFilePath || (this.hasFileNameTarget ? this.fileNameTarget.textContent : "Diff")

    if (this.hasFullscreenFileNameTarget) {
      this.fullscreenFileNameTarget.textContent = fileName
    }

    if (this.hasFullscreenContentTarget && this._currentDiffString) {
      // Re-render in fullscreen with potentially side-by-side (more room)
      const html = this._generateDiffHtml(this._currentDiffString, "side-by-side")
      this.fullscreenContentTarget.innerHTML = html
      this._attachCollapsibleHandlers(this.fullscreenContentTarget)
    } else if (this.hasFullscreenContentTarget && this.hasDiffContentTarget) {
      this.fullscreenContentTarget.innerHTML = this.diffContentTarget.innerHTML
    }

    // Move to body to escape containing block
    this._originalParent = modal.parentElement
    document.body.appendChild(modal)
    document.body.style.overflow = "hidden"

    modal.classList.remove("hidden")
    modal.offsetHeight
    modal.style.opacity = "0"
    requestAnimationFrame(() => {
      modal.style.transition = "opacity 150ms ease-out"
      modal.style.opacity = "1"
    })

    document.addEventListener("keydown", this._handleEscape)
  }

  collapse() {
    const modal = this.fullscreenModalTarget
    if (!modal) return

    document.body.style.overflow = ""

    modal.style.transition = "opacity 150ms ease-in"
    modal.style.opacity = "0"

    setTimeout(() => {
      modal.classList.add("hidden")
      modal.style.opacity = ""
      modal.style.transition = ""

      if (this.hasFullscreenContentTarget) {
        this.fullscreenContentTarget.innerHTML = ""
      }

      if (this._originalParent) {
        this._originalParent.appendChild(modal)
      }
    }, 150)

    document.removeEventListener("keydown", this._handleEscape)
  }

  // ===== Private Methods =====

  _renderDiff() {
    if (!this._currentDiffString) return

    const target = this.hasDiffContentTarget ? this.diffContentTarget : null
    if (!target) return

    const html = this._generateDiffHtml(this._currentDiffString, this.outputTypeValue)
    target.innerHTML = html
    this._attachCollapsibleHandlers(target)
  }

  _generateDiffHtml(diffString, outputFormat) {
    // Check if diff2html is available
    if (typeof window.Diff2Html === "undefined") {
      console.warn("diff2html not loaded, falling back to plain rendering")
      return this._plainDiffHtml(diffString)
    }

    try {
      const html = window.Diff2Html.html(diffString, {
        drawFileList: false,
        matching: "lines",
        outputFormat: outputFormat || "line-by-line",
        renderNothingWhenEmpty: false,
        colorScheme: "dark",
        rawTemplates: {}
      })

      // Wrap with view toggle controls
      return `
        <div class="diff-viewer-enhanced">
          <div class="flex items-center justify-between mb-3 px-1">
            <div class="diff-summary-inline flex items-center gap-3 text-xs">
              ${this._computeStats(diffString)}
            </div>
            <div class="diff-view-toggle">
              <button type="button" 
                      class="${outputFormat !== 'side-by-side' ? 'active' : ''}"
                      data-view-mode="line-by-line"
                      data-diff-viewer-target="viewToggle"
                      data-action="click->diff-viewer#toggleView">
                Unified
              </button>
              <button type="button"
                      class="${outputFormat === 'side-by-side' ? 'active' : ''}"
                      data-view-mode="side-by-side"
                      data-diff-viewer-target="viewToggle"
                      data-action="click->diff-viewer#toggleView">
                Split
              </button>
            </div>
          </div>
          <div class="diff2html-output">
            ${html}
          </div>
        </div>
      `
    } catch (error) {
      console.error("diff2html render error:", error)
      return this._plainDiffHtml(diffString)
    }
  }

  _computeStats(diffString) {
    const lines = diffString.split("\n")
    let additions = 0
    let deletions = 0
    let files = new Set()

    for (const line of lines) {
      if (line.startsWith("+++ b/") || line.startsWith("+++ ")) {
        const name = line.replace(/^\+\+\+ [ab]\//, "").replace(/^\+\+\+ /, "")
        if (name && name !== "/dev/null") files.add(name)
      } else if (line.startsWith("+") && !line.startsWith("+++")) {
        additions++
      } else if (line.startsWith("-") && !line.startsWith("---")) {
        deletions++
      }
    }

    const parts = []
    if (files.size > 0) {
      parts.push(`<span class="text-content-secondary">${files.size} file${files.size > 1 ? "s" : ""}</span>`)
    }
    if (additions > 0) {
      parts.push(`<span class="text-green-400">+${additions}</span>`)
    }
    if (deletions > 0) {
      parts.push(`<span class="text-red-400">-${deletions}</span>`)
    }

    return parts.join('<span class="text-content-muted mx-1">·</span>')
  }

  _attachCollapsibleHandlers(container) {
    if (!container) return

    // Make file headers clickable for collapse
    const headers = container.querySelectorAll(".d2h-file-header")
    headers.forEach(header => {
      // Add collapse icon if not present
      if (!header.querySelector(".collapse-icon")) {
        const nameWrapper = header.querySelector(".d2h-file-name-wrapper")
        if (nameWrapper) {
          const icon = document.createElement("span")
          icon.className = "collapse-icon"
          icon.textContent = "▼"
          nameWrapper.insertBefore(icon, nameWrapper.firstChild)
        }
      }

      // Add click handler
      if (!header._collapseHandlerAttached) {
        header.addEventListener("click", (e) => {
          // Don't collapse when clicking links or buttons inside
          if (e.target.closest("a, button")) return
          this.toggleFileCollapse(e)
        })
        header._collapseHandlerAttached = true
      }
    })
  }

  _plainDiffHtml(diffString) {
    // Fallback plain text rendering when diff2html isn't available
    const escaped = diffString
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
    
    const lines = escaped.split("\n").map(line => {
      let cls = "text-content-secondary"
      if (line.startsWith("+") && !line.startsWith("+++")) cls = "text-green-400 bg-green-900/20"
      else if (line.startsWith("-") && !line.startsWith("---")) cls = "text-red-400 bg-red-900/20"
      else if (line.startsWith("@@")) cls = "text-blue-400 bg-blue-900/10"
      else if (line.startsWith("diff ")) cls = "text-content font-semibold"
      return `<div class="${cls} px-3 py-0.5 font-mono text-xs whitespace-pre">${line}</div>`
    }).join("\n")

    return `<div class="bg-bg-elevated rounded-lg overflow-hidden border border-border">${lines}</div>`
  }

  async _loadDiffHtmlFallback(diffUrl, filePath) {
    try {
      const response = await fetch(diffUrl, {
        headers: { "Accept": "text/html" }
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const html = await response.text()
      
      if (this.hasDiffContentTarget) {
        this.diffContentTarget.innerHTML = html
      }
      
      if (this.hasFileNameTarget) {
        this.fileNameTarget.textContent = filePath
      }
    } catch (error) {
      console.error("Diff HTML fallback error:", error)
      if (this.hasDiffContentTarget) {
        this.diffContentTarget.innerHTML = this._errorHtml(error.message)
      }
    }
  }

  _loadingHtml() {
    return `
      <div class="flex items-center justify-center py-12">
        <div class="flex items-center gap-2 text-content-muted">
          <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm">Loading diff...</span>
        </div>
      </div>
    `
  }

  _errorHtml(message) {
    return `
      <div class="flex items-center justify-center py-12">
        <div class="text-center">
          <span class="text-3xl mb-3 block">⚠️</span>
          <p class="text-sm text-red-400">Failed to load diff: ${message}</p>
        </div>
      </div>
    `
  }

  _handleEscape(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.collapse()
    }
  }
}
