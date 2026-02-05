import { Controller } from "@hotwired/stimulus"
import { subscribeToAgentActivity } from "channels"

export default class extends Controller {
  static targets = ["log", "emptyState", "loadingState", "statusBadge"]
  static values = { 
    taskId: Number,
    sessionId: String,
    taskStatus: String,
    pollInterval: { type: Number, default: 2500 }
  }

  connect() {
    this.lastLine = 0
    this.isPolling = false
    this.pollTimer = null
    this.wsConnected = false
    this.subscription = null
    
    if (this.sessionIdValue) {
      // Try WebSocket first
      this.connectWebSocket()
      // Start polling immediately as fallback (will be disabled if WS connects)
      this.startPolling()
    } else {
      this.showEmptyState()
    }
  }

  disconnect() {
    this.stopPolling()
    this.disconnectWebSocket()
  }

  connectWebSocket() {
    if (!this.taskIdValue) return
    
    try {
      this.subscription = subscribeToAgentActivity(this.taskIdValue, {
        onConnected: () => {
          this.wsConnected = true
          this.stopPolling() // Disable polling when WebSocket is active
          console.log("[AgentActivity] WebSocket connected, polling disabled")
        },
        onDisconnected: () => {
          this.wsConnected = false
          // Re-enable polling as fallback if we should still be polling
          if (this.shouldPoll()) {
            this.startPolling()
          }
          console.log("[AgentActivity] WebSocket disconnected, polling enabled")
        },
        onReceived: (data) => {
          // Trigger poll/fetch when we get a message
          if (data.type === "activity" || data.type === "status") {
            this.poll() // Fetch latest data
          }
        }
      })
    } catch (error) {
      console.warn("[AgentActivity] WebSocket connection failed:", error)
      // Polling is already started as fallback
    }
  }

  disconnectWebSocket() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    this.wsConnected = false
  }

  shouldPoll() {
    return ['in_progress', 'up_next'].includes(this.taskStatusValue)
  }

  startPolling() {
    if (this.isPolling) return
    this.isPolling = true
    this.poll()
    console.log("[AgentActivity] Polling started")
  }

  stopPolling() {
    this.isPolling = false
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)
      this.pollTimer = null
    }
    console.log("[AgentActivity] Polling stopped")
  }

  async poll() {
    // Only skip if we're in polling mode AND not actively polling
    // When WS triggers poll(), we should always fetch
    if (this.isPolling === false && !this.wsConnected) return
    
    try {
      const response = await fetch(`/api/v1/tasks/${this.taskIdValue}/agent_log?since=${this.lastLine}`)
      
      if (!response.ok) {
        console.error('Fetch failed:', response.status)
        this.scheduleNextPoll()
        return
      }

      const data = await response.json()
      
      if (data.task_status) {
        this.taskStatusValue = data.task_status
        this.updateStatusBadge(data.task_status)
      }

      if (!data.has_session) {
        this.showEmptyState()
        this.stopPolling()
        return
      }

      if (data.messages && data.messages.length > 0) {
        this.hideEmptyState()
        this.hideLoadingState()
        data.messages.forEach(msg => this.renderMessage(msg))
        this.lastLine = data.total_lines
        this.scrollToBottom()
      } else if (this.lastLine === 0) {
        this.hideLoadingState()
        if (data.has_session) {
          this.showWaitingState(data.task_status)
        } else {
          this.showEmptyState()
        }
      }

      // Stop polling if task is complete (but keep WS for final updates)
      if (!this.shouldPoll()) {
        this.stopPolling()
        return
      }

    } catch (error) {
      console.error('Poll error:', error)
    }

    this.scheduleNextPoll()
  }

  scheduleNextPoll() {
    // Only schedule next poll if we're in polling mode (not WS mode)
    if (!this.isPolling || this.wsConnected) return
    this.pollTimer = setTimeout(() => this.poll(), this.pollIntervalValue)
  }

  renderMessage(msg) {
    const container = this.logTarget
    const div = document.createElement('div')
    div.className = 'agent-log-entry mb-3'
    
    let icon = '📝'
    let roleClass = 'border-content-muted'
    if (msg.role === 'user') { icon = '👤'; roleClass = 'border-blue-500' }
    if (msg.role === 'assistant') { icon = '🤖'; roleClass = 'border-purple-500' }
    if (msg.role === 'toolResult') { icon = '⚙️'; roleClass = 'border-green-500' }
    
    let contentHtml = ''
    if (msg.content && Array.isArray(msg.content)) {
      msg.content.forEach(item => {
        if (item.type === 'text' && item.text) {
          // User messages and text content - show full text in panel
          const text = item.text.length > 5000 ? item.text.substring(0, 5000) + '...' : item.text
          contentHtml += `<div class="text-sm text-content whitespace-pre-wrap break-words">${this.escapeHtml(text)}</div>`
        }
        if (item.type === 'thinking' && item.text) {
          // Assistant thinking
          const thinking = item.text.length > 1500 ? item.text.substring(0, 1500) + '...' : item.text
          contentHtml += `<div class="text-xs text-content-muted italic bg-bg-surface/50 rounded px-2 py-1 mt-1">💭 ${this.escapeHtml(thinking)}</div>`
        }
        if (item.type === 'tool_call') {
          contentHtml += `<div class="text-xs font-mono text-accent mt-1">🔧 ${this.escapeHtml(item.name || 'tool')}</div>`
        }
        if (item.type === 'tool_result' && item.text) {
          // Tool results - show more in panel
          const result = item.text.length > 3000 ? item.text.substring(0, 3000) + '...' : item.text
          contentHtml += `<div class="text-xs font-mono text-content-muted bg-bg-surface rounded px-2 py-1 mt-1 max-h-40 overflow-y-auto whitespace-pre-wrap">${this.escapeHtml(result)}</div>`
        }
      })
    }
    
    div.innerHTML = `
      <div class="flex items-start gap-2 p-2 rounded-lg bg-bg-elevated border-l-2 ${roleClass}">
        <span class="text-sm flex-shrink-0">${icon}</span>
        <div class="flex-1 min-w-0">
          ${contentHtml || '<span class="text-xs text-content-muted">...</span>'}
        </div>
      </div>
    `
    container.appendChild(div)
  }

  scrollToBottom() {
    if (this.hasLogTarget) {
      this.logTarget.scrollTop = this.logTarget.scrollHeight
    }
  }

  showEmptyState() {
    if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.remove('hidden')
    if (this.hasLogTarget) this.logTarget.classList.add('hidden')
    this.hideLoadingState()
  }

  hideEmptyState() {
    if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.add('hidden')
    if (this.hasLogTarget) this.logTarget.classList.remove('hidden')
  }

  showWaitingState(taskStatus = null) {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove('hidden')
      const msgEl = this.emptyStateTarget.querySelector('.empty-message')
      if (msgEl) {
        // For completed tasks, show appropriate message
        const completedStatuses = ['in_review', 'done']
        if (taskStatus && completedStatuses.includes(taskStatus)) {
          msgEl.textContent = 'No activity log available'
        } else {
          msgEl.textContent = 'Waiting for agent...'
        }
      }
    }
    if (this.hasLogTarget) this.logTarget.classList.add('hidden')
  }

  showLoadingState() {
    if (this.hasLoadingStateTarget) this.loadingStateTarget.classList.remove('hidden')
  }

  hideLoadingState() {
    if (this.hasLoadingStateTarget) this.loadingStateTarget.classList.add('hidden')
  }

  updateStatusBadge(status) {
    if (!this.hasStatusBadgeTarget) return
    const labels = { in_progress: 'Live', up_next: 'Up Next', done: 'Done', in_review: 'In Review' }
    this.statusBadgeTarget.textContent = labels[status] || status
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  refresh() {
    this.lastLine = 0
    if (this.hasLogTarget) this.logTarget.innerHTML = ''
    if (!this.isPolling && !this.wsConnected) this.startPolling()
    else this.poll()
  }
}
