import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="task-modal"
// Handles both mobile slide-in panel and desktop full-screen modal
export default class extends Controller {
  static targets = ["modal", "backdrop", "dragHandle", "form", "nameField", "descriptionField", "submitButton", "priorityField", "priorityButton", "priorityGroup", "dueDateField", "dueDateDisplay", "recurringCheckbox", "recurringOptions", "nightlyCheckbox", "nightlyOptions", "personaSelect", "personaPill", "personaClear"]
  static values = { taskId: Number }

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.boundResizeDescription = this.resizeDescription.bind(this)
    this.autoSaveTimeout = null
    this.isDesktop = window.matchMedia("(min-width: 1024px)").matches

    // Listen for resize to update mode
    this.resizeHandler = () => {
      this.isDesktop = window.matchMedia("(min-width: 1024px)").matches
    }
    window.addEventListener("resize", this.resizeHandler)

    // Auto-open the modal when it's loaded
    setTimeout(() => {
      this.open()
      this.resizeDescription()
      this.updatePriorityUI()
      this.updatePersonaUI()
      if (this.isDesktop) this.initDrag()
    }, 10)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    window.removeEventListener("resize", this.resizeHandler)
    // Clear any pending auto-save
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
    }
  }

  open(event) {
    // Prevent the click from bubbling up to the card
    if (event) {
      event.stopPropagation()
    }

    // Add document-level listener for ESC key
    document.addEventListener("keydown", this.boundHandleKeydown)

    // Show backdrop
    this.backdropTarget.classList.remove("hidden")
    setTimeout(() => {
      this.backdropTarget.classList.remove("opacity-0")
    }, 10)

    // Show modal
    this.modalTarget.classList.remove("hidden")
    setTimeout(() => {
      if (this.isDesktop) {
        // Desktop: fade + scale in
        this.modalTarget.classList.remove("lg:opacity-0", "lg:scale-95")
      } else {
        // Mobile: slide in from right
        this.modalTarget.classList.remove("translate-x-full")
      }
    }, 10)
  }

  initDrag() {
    if (!this.hasDragHandleTarget) return
    const win = this.dragHandleTarget
    const modal = this.modalTarget
    if (win._dragInit) return
    win._dragInit = true

    // Position window centered on first open
    const w = Math.min(900, window.innerWidth * 0.88)
    const h = Math.min(window.innerHeight * 0.88, 800)
    const left = Math.max(0, (window.innerWidth - w) / 2)
    const top  = Math.max(0, (window.innerHeight - h) / 2)
    modal.style.cssText = `position:fixed; inset:auto; left:${left}px; top:${top}px; width:${w}px; height:${h}px; margin:0; padding:0;`
    win.style.width  = '100%'
    win.style.height = '100%'

    // Drag from header (first child of win)
    const handle = win.firstElementChild
    if (!handle) return
    handle.style.cursor = 'grab'

    handle.addEventListener('mousedown', (e) => {
      if (e.target.closest('button, a, select, input')) return
      e.preventDefault()
      handle.style.cursor = 'grabbing'
      const startX = e.clientX, startY = e.clientY
      const startL = parseInt(modal.style.left) || 0
      const startT = parseInt(modal.style.top)  || 0

      const onMove = (e) => {
        modal.style.left = Math.max(0, Math.min(window.innerWidth  - 100, startL + e.clientX - startX)) + 'px'
        modal.style.top  = Math.max(0, Math.min(window.innerHeight - 40,  startT + e.clientY - startY)) + 'px'
      }
      const onUp = () => {
        handle.style.cursor = 'grab'
        document.removeEventListener('mousemove', onMove)
        document.removeEventListener('mouseup', onUp)
      }
      document.addEventListener('mousemove', onMove)
      document.addEventListener('mouseup', onUp)
    })
  }

  close() {
    // Save any pending changes before closing
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
      this.autoSaveTimeout = null
      this.save()
    }

    if (this.isDesktop) {
      // Desktop: fade + scale out
      this.modalTarget.classList.add("lg:opacity-0", "lg:scale-95")
    } else {
      // Mobile: slide out to right
      this.modalTarget.classList.add("translate-x-full")
    }
    this.backdropTarget.classList.add("opacity-0")

    setTimeout(() => {
      this.modalTarget.classList.add("hidden")
      this.backdropTarget.classList.add("hidden")

      // Apply any pending turbo stream updates now that modal is closing
      if (this.pendingTurboStream) {
        Turbo.renderStreamMessage(this.pendingTurboStream)
        this.pendingTurboStream = null
      }

      // Clear the turbo frame to remove the panel
      const taskPanelFrame = document.getElementById('task_panel')
      if (taskPanelFrame) {
        taskPanelFrame.innerHTML = ''
      }
    }, 300) // Match the duration-300 transition

    // Remove ESC listener
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  save() {
    // Submit form data via fetch to avoid Turbo navigation/panel closing
    const form = this.formTarget
    const formData = new FormData(form)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(form.action, {
      method: 'PATCH',
      body: formData,
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-CSRF-Token': csrfToken
      },
      credentials: "same-origin"
    }).then(async (response) => {
      if (!response.ok) {
        let details = ""
        try {
          details = await response.text()
        } catch {
          // noop
        }
        console.error("Task modal save failed:", response.status, response.statusText, details)
        return null
      }
      return response.text()
    }).then((html) => {
      if (!html) return
      // Apply updates immediately so the UI reflects changes while the modal is open.
      Turbo.renderStreamMessage(html)
    }).catch((error) => {
      console.error("Task modal save error:", error)
    })
  }

  scheduleAutoSave() {
    // Debounce auto-save to avoid too many requests
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
    }
    this.autoSaveTimeout = setTimeout(() => {
      this.save()
      this.autoSaveTimeout = null
    }, 500) // Save 500ms after user stops typing
  }

  handleKeydown(event) {
    // Close on ESC
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  resizeDescription() {
    if (this.hasDescriptionFieldTarget) {
      const textarea = this.descriptionFieldTarget
      const maxHeight = 256 // max-h-64 = 16rem = 256px
      const minHeight = 80 // 5rem minimum

      // Reset height to 0 to get accurate scrollHeight
      textarea.style.height = '0'

      // Calculate the desired height, respecting min and max
      const desiredHeight = Math.max(textarea.scrollHeight, minHeight)
      const newHeight = Math.min(desiredHeight, maxHeight)

      textarea.style.height = newHeight + 'px'

      // Add input listener to auto-resize as user types
      textarea.addEventListener('input', this.boundResizeDescription)
    }
  }

  selectPriority(event) {
    const value = event.currentTarget.dataset.priorityValue
    if (!value) return
    if (this.hasPriorityFieldTarget) {
      this.priorityFieldTarget.value = value
    }
    this.updatePriorityUI()
    // Auto-save when priority changes
    this.save()
  }

  updatePriorityUI() {
    if (!this.hasPriorityButtonTarget) return
    const current = this.hasPriorityFieldTarget ? this.priorityFieldTarget.value : 'none'
    this.priorityButtonTargets.forEach((btn) => {
      const val = btn.dataset.priorityValue
      const isSelected = (val === current)
      btn.setAttribute('aria-pressed', isSelected ? 'true' : 'false')
    })
  }

  onDueDateChange() {
    // Due date changed via datepicker - save the form
    this.save()
  }

  async recoverOutput(event) {
    event.preventDefault()

    const button = event.currentTarget
    const url = button.dataset.recoverUrl
    if (!url) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    button.disabled = true
    const originalText = button.textContent
    button.textContent = '⏳ Recuperando...'

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        }
      })

      const data = await response.json()

      if (!response.ok) {
        alert(data?.error || 'No transcript found. Use manual edit.')
        return
      }

      if (this.hasDescriptionFieldTarget) {
        this.descriptionFieldTarget.value = data?.description || ''
        this.resizeDescription()
      }

      this.save()
    } catch (error) {
      alert('No transcript found. Use manual edit.')
    } finally {
      button.disabled = false
      button.textContent = originalText
    }
  }

  focusDescription(event) {
    event.preventDefault()
    if (!this.hasDescriptionFieldTarget) return

    this.descriptionFieldTarget.focus()
    this.descriptionFieldTarget.setSelectionRange(
      this.descriptionFieldTarget.value.length,
      this.descriptionFieldTarget.value.length
    )
  }



  stopEvent(event) {
    // Some ancestors (cards/backdrops) use click handlers; stop early so controls remain usable.
    event.preventDefault()
    event.stopPropagation()
  }

  clearPersona(event) {
    event.preventDefault()
    event.stopPropagation()
    if (typeof event.stopImmediatePropagation === "function") event.stopImmediatePropagation()

    if (this.hasPersonaSelectTarget) {
      this.personaSelectTarget.value = ""
    }

    this.updatePersonaUI()

    // Persist immediately
    this.save()
  }

  onPersonaChange() {
    this.updatePersonaUI()
    this.scheduleAutoSave()
  }

  updatePersonaUI() {
    if (!this.hasPersonaSelectTarget) return

    const selected = this.personaSelectTarget.selectedOptions?.[0]
    const hasPersona = !!(this.personaSelectTarget.value && this.personaSelectTarget.value.trim().length > 0)

    if (this.hasPersonaPillTarget) {
      if (hasPersona && selected) {
        // Option label format: "🤖 Name (model → fallback)"
        const label = (selected.textContent || "").trim()
        const display = label.replace(/\s*\(.+\)\s*$/, "").trim()
        this.personaPillTarget.textContent = display || label
        this.personaPillTarget.title = label
        this.personaPillTarget.classList.remove("hidden")
      } else {
        this.personaPillTarget.textContent = ""
        this.personaPillTarget.title = ""
        this.personaPillTarget.classList.add("hidden")
      }
    }

    if (this.hasPersonaClearTarget) {
      if (hasPersona) {
        this.personaClearTarget.classList.remove("hidden")
      } else {
        this.personaClearTarget.classList.add("hidden")
      }
    }
  }
  toggleRecurring() {
    if (!this.hasRecurringOptionsTarget) return
    const checkbox = this.recurringCheckboxTarget
    if (checkbox.checked) {
      this.recurringOptionsTarget.classList.remove('hidden')
    } else {
      this.recurringOptionsTarget.classList.add('hidden')
    }
  }

  toggleNightly() {
    if (!this.hasNightlyOptionsTarget) return
    const checkbox = this.nightlyCheckboxTarget
    if (checkbox.checked) {
      this.nightlyOptionsTarget.classList.remove('hidden')
    } else {
      this.nightlyOptionsTarget.classList.add('hidden')
    }
  }
}
