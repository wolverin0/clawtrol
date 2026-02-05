import { Controller } from "@hotwired/stimulus"

// Displays model rate limit status in the header
// Shows which models are available/limited with visual indicators and progress bars
export default class extends Controller {
  static targets = ["container", "badge", "dropdown"]
  static values = {
    url: String,
    interval: { type: Number, default: 30000 } // Check every 30 seconds
  }

  connect() {
    this.fetchStatus()
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
    this.stopProgressUpdates()
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.fetchStatus(), this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
    }
  }

  startProgressUpdates() {
    // Update progress bars every second for smooth countdown
    this.progressTimer = setInterval(() => this.updateProgressBars(), 1000)
  }

  stopProgressUpdates() {
    if (this.progressTimer) {
      clearInterval(this.progressTimer)
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
        this.models = data.models || []
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
    const totalCount = models.length
    
    // Always show badge (compact status indicator)
    if (this.hasBadgeTarget) {
      this.badgeTarget.classList.remove('hidden')
      this.badgeTarget.innerHTML = this.renderBadge(limitedModels, availableCount, totalCount)
    }

    // Update dropdown content
    if (this.hasDropdownTarget) {
      this.dropdownTarget.innerHTML = this.renderDropdown(models)
    }

    // Start/stop progress updates based on whether we have limited models
    if (limitedModels.length > 0) {
      this.startProgressUpdates()
    } else {
      this.stopProgressUpdates()
    }
  }

  renderBadge(limitedModels, availableCount, totalCount) {
    const allAvailable = limitedModels.length === 0
    const allLimited = limitedModels.length === totalCount
    
    let statusDot, statusColor
    if (allAvailable) {
      statusDot = 'bg-green-500'
      statusColor = 'text-green-400'
    } else if (allLimited) {
      statusDot = 'bg-red-500'
      statusColor = 'text-red-400'
    } else {
      statusDot = 'bg-yellow-500'
      statusColor = 'text-yellow-400'
    }

    return `
      <div class="flex items-center gap-1.5 cursor-pointer" data-action="click->model-status#toggleDropdown">
        <span class="w-2 h-2 rounded-full ${statusDot} animate-pulse"></span>
        <span class="text-xs ${statusColor}">${availableCount}/${totalCount}</span>
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
        ? '🟢'
        : '🔴'
      
      let statusText = ''
      let progressBar = ''
      let titleAttr = ''
      
      if (model.limited && model.resets_at) {
        const resetsAt = new Date(model.resets_at)
        titleAttr = `title="Resets at: ${resetsAt.toLocaleString()}"`
        statusText = model.resets_in ? `${model.resets_in}` : 'Limited'
        
        // Calculate progress percentage for the progress bar
        // Progress bar fills up as we get closer to reset (countdown visual)
        // 0% = just rate limited, 100% = about to reset
        const now = Date.now()
        const resetTime = resetsAt.getTime()
        const remaining = resetTime - now
        
        // Estimate initial limit duration: typical rate limits are 1h, 6h, 12h, 24h, or 1 week
        // Use the remaining time to guess the original duration
        let estimatedDuration
        if (remaining > 604800000) { // > 7 days
          estimatedDuration = 604800000 * 2 // 2 weeks
        } else if (remaining > 86400000) { // > 1 day
          estimatedDuration = 604800000 // 1 week
        } else if (remaining > 43200000) { // > 12 hours
          estimatedDuration = 86400000 // 1 day
        } else if (remaining > 21600000) { // > 6 hours
          estimatedDuration = 43200000 // 12 hours
        } else if (remaining > 3600000) { // > 1 hour
          estimatedDuration = 21600000 // 6 hours
        } else {
          estimatedDuration = 3600000 // 1 hour
        }
        
        const elapsed = estimatedDuration - remaining
        const progress = Math.max(5, Math.min(95, (elapsed / estimatedDuration) * 100))
        
        // Format reset time (show date if more than 24h away)
        const resetTimeStr = remaining > 86400000 
          ? resetsAt.toLocaleDateString([], {month: 'short', day: 'numeric', hour: '2-digit', minute:'2-digit'})
          : resetsAt.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
        
        progressBar = `
          <div class="mt-1.5 w-full">
            <div class="h-1.5 bg-bg-base rounded-full overflow-hidden">
              <div class="h-full bg-gradient-to-r from-red-500 via-yellow-500 to-green-500 rounded-full transition-all duration-1000"
                   data-model-status-progress="${model.model}"
                   data-resets-at="${model.resets_at}"
                   data-estimated-duration="${estimatedDuration}"
                   style="width: ${progress}%"></div>
            </div>
            <div class="flex justify-between text-[10px] text-content-muted mt-0.5">
              <span data-model-status-remaining="${model.model}">${statusText}</span>
              <span class="opacity-70">🔓 ${resetTimeStr}</span>
            </div>
          </div>
        `
      } else if (model.available) {
        statusText = 'Available'
      }
      
      return `
        <div class="px-3 py-2 hover:bg-bg-elevated transition-colors ${model.limited ? 'bg-red-500/5' : ''}" ${titleAttr}>
          <div class="flex items-center justify-between text-xs">
            <div class="flex items-center gap-2">
              <span class="text-base">${emoji}</span>
              <span class="capitalize font-medium ${model.limited ? 'text-content-muted' : 'text-content'}">${model.model}</span>
            </div>
            <div class="flex items-center gap-2">
              ${!model.limited ? `<span class="text-green-400 text-[10px]">${statusText}</span>` : ''}
              <span>${statusIcon}</span>
            </div>
          </div>
          ${progressBar}
        </div>
      `
    }).join('')

    const limitedCount = models.filter(m => m.limited).length
    const headerStatus = limitedCount === 0 
      ? '<span class="text-green-400">All models available</span>'
      : `<span class="text-yellow-400">${limitedCount} model${limitedCount > 1 ? 's' : ''} rate-limited</span>`

    return `
      <div class="py-1">
        <div class="px-3 py-2 text-xs font-medium text-content border-b border-border flex items-center justify-between">
          <span>Model Status</span>
          ${headerStatus}
        </div>
        ${items}
        <div class="px-3 py-2 text-[10px] text-content-muted border-t border-border flex items-center gap-1">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Auto-refresh every 30s
        </div>
      </div>
    `
  }

  updateProgressBars() {
    const progressBars = this.element.querySelectorAll('[data-model-status-progress]')
    
    progressBars.forEach(bar => {
      const resetsAt = new Date(bar.dataset.resetsAt)
      const estimatedDuration = parseInt(bar.dataset.estimatedDuration) || 3600000
      const now = Date.now()
      const resetTime = resetsAt.getTime()
      
      if (now >= resetTime) {
        // Limit expired, refresh status
        this.fetchStatus()
        return
      }
      
      // Calculate new progress using stored estimated duration
      const remaining = resetTime - now
      const elapsed = estimatedDuration - remaining
      const progress = Math.max(5, Math.min(95, (elapsed / estimatedDuration) * 100))
      
      bar.style.width = `${progress}%`
      
      // Update time remaining text
      const modelName = bar.dataset.modelStatusProgress
      const timeSpan = this.element.querySelector(`[data-model-status-remaining="${modelName}"]`)
      if (timeSpan) {
        const seconds = Math.floor(remaining / 1000)
        if (seconds < 60) {
          timeSpan.textContent = `${seconds}s`
        } else if (seconds < 3600) {
          timeSpan.textContent = `${Math.floor(seconds / 60)}m ${seconds % 60}s`
        } else if (seconds < 86400) {
          const h = Math.floor(seconds / 3600)
          const m = Math.floor((seconds % 3600) / 60)
          timeSpan.textContent = `${h}h ${m}m`
        } else {
          const d = Math.floor(seconds / 86400)
          const h = Math.floor((seconds % 86400) / 3600)
          timeSpan.textContent = `${d}d ${h}h`
        }
      }
    })
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
