import { Controller } from "@hotwired/stimulus"

// Displays model rate limit status in the header
// Shows which models are available/limited with visual indicators
export default class extends Controller {
  static targets = ["container", "badge", "dropdown"]
  static values = {
    url: String,
    interval: { type: Number, default: 60000 } // Check every minute
  }

  connect() {
    this.fetchStatus()
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.fetchStatus(), this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
    }
  }

  async fetchStatus() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        this.updateDisplay(data)
      }
    } catch (error) {
      console.error('Error fetching model status:', error)
    }
  }

  updateDisplay(data) {
    const models = data.models || []
    const limitedModels = models.filter(m => m.limited)
    const availableCount = models.filter(m => m.available).length
    
    // Update badge
    if (this.hasBadgeTarget) {
      if (limitedModels.length > 0) {
        this.badgeTarget.classList.remove('hidden')
        this.badgeTarget.innerHTML = this.renderBadge(limitedModels, availableCount, models.length)
      } else {
        this.badgeTarget.classList.add('hidden')
      }
    }

    // Update dropdown content
    if (this.hasDropdownTarget) {
      this.dropdownTarget.innerHTML = this.renderDropdown(models)
    }
  }

  renderBadge(limitedModels, availableCount, totalCount) {
    const firstLimited = limitedModels[0]
    const resetTime = firstLimited.resets_in || 'soon'
    
    return `
      <div class="flex items-center gap-1.5 cursor-pointer" data-action="click->model-status#toggleDropdown">
        <span class="w-2 h-2 rounded-full ${limitedModels.length === totalCount ? 'bg-red-500' : 'bg-yellow-500'}"></span>
        <span class="text-xs">${availableCount}/${totalCount}</span>
        <svg class="w-3 h-3 text-content-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </div>
    `
  }

  renderDropdown(models) {
    const modelEmoji = {
      'codex': '🧠',
      'opus': '🎭',
      'sonnet': '✨',
      'glm': '🤖',
      'gemini': '💎'
    }

    const items = models.map(model => {
      const emoji = modelEmoji[model.model] || '🤖'
      const statusIcon = model.available 
        ? '<span class="w-2 h-2 rounded-full bg-green-500"></span>'
        : '<span class="w-2 h-2 rounded-full bg-red-500"></span>'
      
      let status = model.available ? 'Available' : `Limited`
      if (model.resets_in) {
        status = `Resets in ${model.resets_in}`
      }
      
      return `
        <div class="flex items-center justify-between px-3 py-2 text-xs hover:bg-bg-elevated transition-colors ${model.limited ? 'text-content-muted' : 'text-content-secondary'}">
          <div class="flex items-center gap-2">
            <span>${emoji}</span>
            <span class="capitalize ${model.limited ? 'line-through' : ''}">${model.model}</span>
          </div>
          <div class="flex items-center gap-2">
            ${model.limited ? `<span class="text-yellow-500">${status}</span>` : ''}
            ${statusIcon}
          </div>
        </div>
      `
    }).join('')

    return `
      <div class="py-1">
        <div class="px-3 py-2 text-xs font-medium text-content border-b border-border">Model Availability</div>
        ${items}
      </div>
    `
  }

  toggleDropdown(event) {
    event.stopPropagation()
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle('hidden')
      
      // Close on click outside
      if (!this.dropdownTarget.classList.contains('hidden')) {
        const closeHandler = (e) => {
          if (!this.element.contains(e.target)) {
            this.dropdownTarget.classList.add('hidden')
            document.removeEventListener('click', closeHandler)
          }
        }
        document.addEventListener('click', closeHandler)
      }
    }
  }

  // Manually clear a limit (calls API)
  async clearLimit(event) {
    const modelName = event.target.dataset.model
    if (!modelName) return

    try {
      const response = await fetch(`/api/v1/models/${modelName}/limit`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        this.fetchStatus() // Refresh display
      }
    } catch (error) {
      console.error('Error clearing model limit:', error)
    }
  }
}
