import { Controller } from "@hotwired/stimulus"

// Undo toast for task status changes
// Shows a toast with countdown timer and undo button after status changes
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 5000 }
  }

  static targets = ["container"]

  connect() {
    this.toasts = []
    document.addEventListener("task:status-changed", this.handleStatusChange.bind(this))
  }

  disconnect() {
    document.removeEventListener("task:status-changed", this.handleStatusChange.bind(this))
    // Clear all pending timers
    this.toasts.forEach(toast => {
      if (toast.timer) clearTimeout(toast.timer)
    })
  }

  handleStatusChange(event) {
    const { taskId, taskName, oldStatus, newStatus, boardId } = event.detail
    if (!taskId || !newStatus || oldStatus === newStatus) return

    this.showToast({ taskId, taskName, oldStatus, newStatus, boardId })
  }

  showToast({ taskId, taskName, oldStatus, newStatus, boardId }) {
    const toastId = `undo-toast-${taskId}-${Date.now()}`
    const statusLabels = {
      inbox: "Inbox",
      up_next: "Up Next",
      in_progress: "In Progress",
      in_review: "In Review",
      done: "Done",
      archived: "Archived"
    }

    const toast = document.createElement("div")
    toast.id = toastId
    toast.className = "bg-bg-elevated border border-border rounded-lg shadow-xl px-4 py-3 flex items-center gap-3 text-sm pointer-events-auto animate-slide-in-up"
    toast.innerHTML = `
      <span class="text-content">Moved "<strong class="font-medium">${this.escapeHtml(taskName)}</strong>" to <strong class="font-medium">${statusLabels[newStatus] || newStatus}</strong></span>
      <button type="button" class="undo-btn text-accent hover:underline font-medium flex-shrink-0">Undo</button>
      <div class="w-16 h-1 bg-bg-base rounded-full overflow-hidden flex-shrink-0">
        <div class="countdown-bar h-full bg-accent rounded-full" style="width: 100%; transition: width ${this.durationValue}ms linear;"></div>
      </div>
    `

    // Store toast metadata
    const toastData = {
      id: toastId,
      taskId,
      oldStatus,
      newStatus,
      boardId,
      element: toast,
      timer: null
    }
    this.toasts.push(toastData)

    // Add to container
    this.containerTarget.appendChild(toast)

    // Start countdown animation after a frame (to trigger transition)
    requestAnimationFrame(() => {
      const bar = toast.querySelector(".countdown-bar")
      if (bar) bar.style.width = "0%"
    })

    // Setup undo button
    const undoBtn = toast.querySelector(".undo-btn")
    undoBtn.addEventListener("click", () => this.handleUndo(toastData))

    // Auto-dismiss after duration
    toastData.timer = setTimeout(() => this.dismissToast(toastData), this.durationValue)
  }

  async handleUndo(toastData) {
    const { taskId, oldStatus, boardId, element, timer } = toastData

    // Clear the dismiss timer
    if (timer) clearTimeout(timer)

    // Disable undo button and show loading state
    const undoBtn = element.querySelector(".undo-btn")
    if (undoBtn) {
      undoBtn.disabled = true
      undoBtn.textContent = "Undoing..."
      undoBtn.classList.add("opacity-50", "cursor-not-allowed")
    }

    try {
      // Get CSRF token
      const csrfToken = document.querySelector("[name='csrf-token']")?.content

      // Call the move endpoint to revert status
      const response = await fetch(`/boards/${boardId}/tasks/${taskId}/move?status=${oldStatus}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        }
      })

      if (response.ok) {
        // Turbo will handle the stream response and update the UI
        const contentType = response.headers.get("content-type")
        if (contentType && contentType.includes("turbo-stream")) {
          const html = await response.text()
          Turbo.renderStreamMessage(html)
        } else {
          // Fallback: reload the page if not a turbo stream
          window.location.reload()
        }
      } else {
        console.error("Failed to undo status change:", response.status)
        // Show error state briefly
        if (undoBtn) {
          undoBtn.textContent = "Failed"
          undoBtn.classList.add("text-red-400")
        }
        // Dismiss after showing error
        setTimeout(() => this.dismissToast(toastData), 1500)
        return
      }
    } catch (error) {
      console.error("Error undoing status change:", error)
      if (undoBtn) {
        undoBtn.textContent = "Error"
        undoBtn.classList.add("text-red-400")
      }
      setTimeout(() => this.dismissToast(toastData), 1500)
      return
    }

    // Remove toast immediately on successful undo
    this.dismissToast(toastData, true)
  }

  dismissToast(toastData, immediate = false) {
    const { element, timer, id } = toastData

    // Clear timer if still pending
    if (timer) clearTimeout(timer)

    // Remove from tracking array
    this.toasts = this.toasts.filter(t => t.id !== id)

    if (immediate) {
      element.remove()
      return
    }

    // Animate out
    element.classList.remove("animate-slide-in-up")
    element.classList.add("animate-slide-out-down")

    // Remove after animation
    setTimeout(() => element.remove(), 200)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
