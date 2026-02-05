import { Controller } from "@hotwired/stimulus"

// Loads and displays a preview of agent transcript
export default class extends Controller {
  static targets = ["content"]
  static values = {
    url: String
  }

  connect() {
    this.loadPreview()
  }

  async loadPreview() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        this.renderPreview(data)
      } else {
        this.contentTarget.innerHTML = '<span class="text-red-400">Failed to load transcript</span>'
      }
    } catch (error) {
      console.error('Error loading agent log preview:', error)
      this.contentTarget.innerHTML = '<span class="text-red-400">Error loading transcript</span>'
    }
  }

  renderPreview(data) {
    if (!data.has_session) {
      this.contentTarget.innerHTML = '<span class="text-content-muted">Waiting for agent connection...</span>'
      return
    }

    if (!data.messages || data.messages.length === 0) {
      this.contentTarget.innerHTML = '<span class="text-content-muted">No activity yet</span>'
      return
    }

    // Get last 5 messages for preview
    const recentMessages = data.messages.slice(-5)
    
    const html = recentMessages.map(msg => {
      const roleLabel = msg.role === 'assistant' ? '🤖' : msg.role === 'user' ? '👤' : '🔧'
      const content = this.extractContent(msg.content)
      return `<div class="mb-2">
        <span class="text-content-muted">${roleLabel}</span>
        <span class="text-content-secondary">${this.escapeHtml(content.slice(0, 200))}${content.length > 200 ? '...' : ''}</span>
      </div>`
    }).join('')

    this.contentTarget.innerHTML = html || '<span class="text-content-muted">No content</span>'
  }

  extractContent(content) {
    if (!content) return ''
    if (Array.isArray(content)) {
      const textItem = content.find(item => item.type === 'text' || item.type === 'tool_result')
      return textItem?.text || ''
    }
    return String(content)
  }

  escapeHtml(str) {
    const div = document.createElement('div')
    div.textContent = str
    return div.innerHTML
  }
}
