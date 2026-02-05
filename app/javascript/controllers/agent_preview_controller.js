import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "pinButton"]
  static values = { 
    taskId: Number,
    boardId: Number,
    taskName: String
  }

  connect() {
    this.polling = false
    console.log("[agent-preview] connected for task", this.taskIdValue)
  }

  disconnect() {
    this.stopPolling()
  }

  show() {
    console.log("[agent-preview] show() called, hasPreviewTarget:", this.hasPreviewTarget)
    if (!this.hasPreviewTarget) return
    this.previewTarget.classList.remove("hidden")
    this.startPolling()
  }

  hide() {
    if (!this.hasPreviewTarget) return
    this.previewTarget.classList.add("hidden")
    this.stopPolling()
  }

  startPolling() {
    this.polling = true
    this.poll()
  }

  stopPolling() {
    this.polling = false
  }

  async poll() {
    if (!this.polling) return
    
    try {
      const response = await fetch(`/api/v1/tasks/${this.taskIdValue}/agent_log?limit=3`)
      if (response.ok) {
        const data = await response.json()
        this.renderPreview(data.messages || [])
      }
    } catch (e) {
      console.error("Preview poll failed:", e)
    }

    if (this.polling) {
      setTimeout(() => this.poll(), 2000)
    }
  }

  renderPreview(messages) {
    if (!this.hasPreviewTarget) return
    
    // Build preview content with pin button
    let previewContent = ''
    
    if (messages.length === 0) {
      previewContent = '<span class="text-content-muted text-xs">Waiting for agent...</span>'
    } else {
      previewContent = messages.slice(-3).map(m => {
        const icon = m.role === 'user' ? '👤' : '🤖'
        const rawContent = this.extractContent(m.content)
        const text = this.escapeHtml(rawContent.substring(0, 100))
        const ellipsis = rawContent.length > 100 ? '...' : ''
        return `<div class="text-xs truncate text-content-secondary">${icon} ${text}${ellipsis}</div>`
      }).join('')
    }
    
    // Add pin button
    const pinButton = `
      <button 
        data-action="click->agent-preview#pinToTerminal"
        class="mt-2 w-full flex items-center justify-center gap-1 px-2 py-1 text-[10px] font-medium text-green-400 bg-green-500/10 hover:bg-green-500/20 border border-green-500/30 rounded transition-colors"
        title="Pin to Agent Terminal"
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3">
          <path stroke-linecap="round" stroke-linejoin="round" d="m6.75 7.5 3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0 0 21 18V6a2.25 2.25 0 0 0-2.25-2.25H5.25A2.25 2.25 0 0 0 3 6v12a2.25 2.25 0 0 0 2.25 2.25Z" />
        </svg>
        PIN TO TERMINAL
      </button>
    `
    
    this.previewTarget.innerHTML = previewContent + pinButton
  }

  pinToTerminal(event) {
    event.preventDefault()
    event.stopPropagation()
    
    console.log("[agent-preview] Pin to terminal clicked for task", this.taskIdValue)
    
    // Dispatch custom event that the terminal controller listens to
    const pinEvent = new CustomEvent('agent-terminal:pin', {
      bubbles: true,
      detail: {
        taskId: this.taskIdValue,
        taskName: this.taskNameValue || `Task #${this.taskIdValue}`
      }
    })
    
    document.dispatchEvent(pinEvent)
    
    // Hide the preview after pinning
    this.hide()
  }

  extractContent(content) {
    if (!content) return ''
    if (typeof content === 'string') return content
    if (Array.isArray(content)) {
      // Find first text-type content item
      const textItem = content.find(c => c.type === 'text' || c.type === 'tool_result')
      return textItem?.text || ''
    }
    return ''
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
