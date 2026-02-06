import { Controller } from "@hotwired/stimulus"
import { subscribeToAgentActivity } from "channels"

/**
 * Agent Activity Controller - Enhanced terminal view with filtering, search, and timeline
 * 
 * Features:
 * - Smart filtering: Tool calls collapsed by default, expandable
 * - Progress indicators with meaningful icons
 * - Mini timeline showing agent steps
 * - In-terminal search (Ctrl+F)
 */
export default class extends Controller {
  static targets = [
    "log", 
    "emptyState", 
    "loadingState", 
    "statusBadge",
    // New targets for enhanced features
    "filterToggle",
    "searchInput",
    "searchContainer",
    "searchCount",
    "timeline",
    "timelineContainer"
  ]
  
  static values = { 
    taskId: Number,
    sessionId: String,
    taskStatus: String,
    pollInterval: { type: Number, default: 2500 },
    compactMode: { type: Boolean, default: true },
    searchQuery: { type: String, default: "" }
  }

  connect() {
    this.lastLine = 0
    this.isPolling = false
    this.pollTimer = null
    this.wsConnected = false
    this.subscription = null
    this.allMessages = [] // Store all messages for filtering/search
    this.searchMatches = [] // Current search matches
    this.currentMatchIndex = -1
    this.timelineSteps = [] // Parsed timeline steps
    
    // Setup keyboard shortcut for search
    this.setupKeyboardShortcuts()
    
    if (this.sessionIdValue) {
      this.connectWebSocket()
      this.startPolling()
    } else {
      // Even without a session ID, try one poll - the API may return
      // fallback content from task description or output_files
      this.pollOnce()
    }
  }

  disconnect() {
    this.stopPolling()
    this.disconnectWebSocket()
    this.removeKeyboardShortcuts()
  }

  // ========================================
  // KEYBOARD SHORTCUTS
  // ========================================

  setupKeyboardShortcuts() {
    this.keydownHandler = (event) => {
      // Ctrl+F for search (when focused on terminal area)
      if ((event.ctrlKey || event.metaKey) && event.key === 'f') {
        if (this.element.contains(document.activeElement) || this.hasLogTarget) {
          event.preventDefault()
          this.toggleSearch()
        }
      }
      // Escape to close search
      if (event.key === 'Escape' && this.hasSearchContainerTarget && !this.searchContainerTarget.classList.contains('hidden')) {
        this.closeSearch()
      }
      // Enter/Shift+Enter for next/prev match
      if (event.key === 'Enter' && this.hasSearchInputTarget && document.activeElement === this.searchInputTarget) {
        event.preventDefault()
        if (event.shiftKey) {
          this.prevMatch()
        } else {
          this.nextMatch()
        }
      }
    }
    document.addEventListener('keydown', this.keydownHandler)
  }

  removeKeyboardShortcuts() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }

  // ========================================
  // SEARCH FUNCTIONALITY
  // ========================================

  toggleSearch() {
    if (!this.hasSearchContainerTarget) return
    
    const isHidden = this.searchContainerTarget.classList.contains('hidden')
    if (isHidden) {
      this.searchContainerTarget.classList.remove('hidden')
      if (this.hasSearchInputTarget) {
        this.searchInputTarget.focus()
        this.searchInputTarget.select()
      }
    } else {
      this.closeSearch()
    }
  }

  closeSearch() {
    if (this.hasSearchContainerTarget) {
      this.searchContainerTarget.classList.add('hidden')
    }
    this.clearSearchHighlights()
    this.searchQueryValue = ""
    this.searchMatches = []
    this.currentMatchIndex = -1
    this.updateSearchCount()
  }

  performSearch(event) {
    const query = event?.target?.value || this.searchQueryValue
    this.searchQueryValue = query
    
    if (!query || query.length < 2) {
      this.clearSearchHighlights()
      this.searchMatches = []
      this.currentMatchIndex = -1
      this.updateSearchCount()
      return
    }
    
    this.highlightMatches(query)
    this.updateSearchCount()
    
    // Jump to first match
    if (this.searchMatches.length > 0 && this.currentMatchIndex === -1) {
      this.currentMatchIndex = 0
      this.scrollToMatch(0)
    }
  }

  highlightMatches(query) {
    if (!this.hasLogTarget) return
    
    this.clearSearchHighlights()
    this.searchMatches = []
    
    const regex = new RegExp(`(${this.escapeRegex(query)})`, 'gi')
    const entries = this.logTarget.querySelectorAll('.agent-log-entry')
    
    entries.forEach((entry, entryIndex) => {
      const textNodes = this.getTextNodes(entry)
      textNodes.forEach(node => {
        const text = node.textContent
        if (regex.test(text)) {
          const span = document.createElement('span')
          span.innerHTML = text.replace(regex, '<mark class="search-highlight bg-yellow-400/60 text-black rounded px-0.5">$1</mark>')
          node.parentNode.replaceChild(span, node)
          
          // Track matches for navigation
          const marks = span.querySelectorAll('mark')
          marks.forEach(mark => {
            this.searchMatches.push({ element: mark, entryIndex })
          })
        }
      })
    })
  }

  clearSearchHighlights() {
    if (!this.hasLogTarget) return
    
    const highlights = this.logTarget.querySelectorAll('mark.search-highlight')
    highlights.forEach(mark => {
      const text = document.createTextNode(mark.textContent)
      mark.parentNode.replaceChild(text, mark)
    })
    
    // Clean up wrapper spans
    const wrappers = this.logTarget.querySelectorAll('span:not([class])')
    wrappers.forEach(span => {
      if (span.childNodes.length === 1 && span.childNodes[0].nodeType === 3) {
        span.parentNode.replaceChild(span.childNodes[0], span)
      }
    })
  }

  getTextNodes(element) {
    const nodes = []
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null, false)
    let node
    while (node = walker.nextNode()) {
      if (node.textContent.trim()) {
        nodes.push(node)
      }
    }
    return nodes
  }

  nextMatch() {
    if (this.searchMatches.length === 0) return
    this.currentMatchIndex = (this.currentMatchIndex + 1) % this.searchMatches.length
    this.scrollToMatch(this.currentMatchIndex)
    this.updateSearchCount()
  }

  prevMatch() {
    if (this.searchMatches.length === 0) return
    this.currentMatchIndex = this.currentMatchIndex <= 0 
      ? this.searchMatches.length - 1 
      : this.currentMatchIndex - 1
    this.scrollToMatch(this.currentMatchIndex)
    this.updateSearchCount()
  }

  scrollToMatch(index) {
    const match = this.searchMatches[index]
    if (!match) return
    
    // Remove active class from all
    this.searchMatches.forEach(m => m.element.classList.remove('ring-2', 'ring-accent'))
    
    // Add active class to current
    match.element.classList.add('ring-2', 'ring-accent')
    match.element.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }

  updateSearchCount() {
    if (!this.hasSearchCountTarget) return
    
    if (this.searchMatches.length === 0) {
      this.searchCountTarget.textContent = this.searchQueryValue?.length >= 2 ? 'No matches' : ''
    } else {
      this.searchCountTarget.textContent = `${this.currentMatchIndex + 1}/${this.searchMatches.length}`
    }
  }

  escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  }

  // ========================================
  // FILTERING & COMPACT MODE
  // ========================================

  toggleCompactMode() {
    this.compactModeValue = !this.compactModeValue
    this.updateFilterToggleButton()
    this.rerenderAllMessages()
  }

  updateFilterToggleButton() {
    if (!this.hasFilterToggleTarget) return
    
    const icon = this.compactModeValue ? '📋' : '📄'
    const label = this.compactModeValue ? 'Compact' : 'Expanded'
    this.filterToggleTarget.innerHTML = `${icon} ${label}`
  }

  expandToolCall(event) {
    const entry = event.currentTarget.closest('.tool-call-entry')
    if (!entry) return
    
    const content = entry.querySelector('.tool-call-content')
    const chevron = entry.querySelector('.tool-call-chevron')
    
    if (content.classList.contains('hidden')) {
      content.classList.remove('hidden')
      chevron?.classList.add('rotate-90')
    } else {
      content.classList.add('hidden')
      chevron?.classList.remove('rotate-90')
    }
  }

  // ========================================
  // TIMELINE FUNCTIONALITY
  // ========================================

  parseTimelineSteps() {
    // Reset timeline
    this.timelineSteps = []
    const stepCounts = {
      read: 0,
      write: 0,
      exec: 0,
      search: 0,
      thinking: 0,
      text: 0
    }
    
    this.allMessages.forEach(msg => {
      if (!msg.content) return
      
      msg.content.forEach(item => {
        const stepType = this.getStepType(item, msg)
        if (stepType && stepCounts[stepType] !== undefined) {
          stepCounts[stepType]++
        }
      })
    })
    
    // Build timeline steps with counts
    if (stepCounts.read > 0) {
      this.timelineSteps.push({ icon: '📄', label: `Read ${stepCounts.read} file${stepCounts.read > 1 ? 's' : ''}`, type: 'read' })
    }
    if (stepCounts.write > 0) {
      this.timelineSteps.push({ icon: '✏️', label: `Edited ${stepCounts.write} file${stepCounts.write > 1 ? 's' : ''}`, type: 'write' })
    }
    if (stepCounts.exec > 0) {
      this.timelineSteps.push({ icon: '⚙️', label: `Ran ${stepCounts.exec} command${stepCounts.exec > 1 ? 's' : ''}`, type: 'exec' })
    }
    if (stepCounts.search > 0) {
      this.timelineSteps.push({ icon: '🔍', label: `${stepCounts.search} search${stepCounts.search > 1 ? 'es' : ''}`, type: 'search' })
    }
    if (stepCounts.thinking > 0) {
      this.timelineSteps.push({ icon: '🧠', label: `${stepCounts.thinking} reasoning`, type: 'thinking' })
    }
    
    // Add completion indicator if task is done
    if (['done', 'in_review'].includes(this.taskStatusValue)) {
      this.timelineSteps.push({ icon: '✅', label: 'Complete', type: 'complete' })
    }
    
    this.renderTimeline()
  }

  getStepType(item, msg) {
    if (item.type === 'thinking') return 'thinking'
    if (item.type === 'tool_call') {
      const name = (item.name || '').toLowerCase()
      if (name.includes('read') || name.includes('file')) return 'read'
      if (name.includes('write') || name.includes('edit')) return 'write'
      if (name.includes('exec') || name.includes('shell') || name.includes('process')) return 'exec'
      if (name.includes('search') || name.includes('web_search') || name.includes('web_fetch')) return 'search'
      return 'exec' // Default tool calls to exec
    }
    if (item.type === 'tool_result') {
      const toolName = (msg.tool_name || '').toLowerCase()
      if (toolName.includes('read')) return 'read'
      if (toolName.includes('write') || toolName.includes('edit')) return 'write'
      if (toolName.includes('exec')) return 'exec'
      if (toolName.includes('search') || toolName.includes('fetch')) return 'search'
    }
    return null
  }

  renderTimeline() {
    if (!this.hasTimelineTarget || !this.hasTimelineContainerTarget) return
    
    if (this.timelineSteps.length === 0) {
      this.timelineContainerTarget.classList.add('hidden')
      return
    }
    
    this.timelineContainerTarget.classList.remove('hidden')
    
    const html = this.timelineSteps.map((step, index) => {
      const isLast = index === this.timelineSteps.length - 1
      const connector = isLast ? '' : '<span class="text-content-muted mx-1">→</span>'
      
      return `
        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium 
                     ${step.type === 'complete' ? 'bg-green-500/20 text-green-400' : 'bg-bg-surface text-content-secondary'}
                     whitespace-nowrap">
          <span class="mr-1">${step.icon}</span>
          ${step.label}
        </span>
        ${connector}
      `
    }).join('')
    
    this.timelineTarget.innerHTML = html
  }

  // ========================================
  // WEBSOCKET & POLLING (existing functionality)
  // ========================================

  connectWebSocket() {
    if (!this.taskIdValue) return
    
    try {
      this.subscription = subscribeToAgentActivity(this.taskIdValue, {
        onConnected: () => {
          this.wsConnected = true
          this.stopPolling()
          console.log("[AgentActivity] WebSocket connected, polling disabled")
        },
        onDisconnected: () => {
          this.wsConnected = false
          if (this.shouldPoll()) {
            this.startPolling()
          }
          console.log("[AgentActivity] WebSocket disconnected, polling enabled")
        },
        onReceived: (data) => {
          if (data.type === "activity" || data.type === "status") {
            this.poll()
          }
        }
      })
    } catch (error) {
      console.warn("[AgentActivity] WebSocket connection failed:", error)
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

  // Single poll attempt for tasks without session ID (fallback content)
  async pollOnce() {
    try {
      const response = await fetch(`/api/v1/tasks/${this.taskIdValue}/agent_log?since=0`)
      if (!response.ok) {
        this.showEmptyState()
        return
      }
      const data = await response.json()
      if (data.messages && data.messages.length > 0) {
        this.hideEmptyState()
        this.hideLoadingState()
        data.messages.forEach(msg => {
          this.allMessages.push(msg)
          this.renderMessage(msg)
        })
        this.lastLine = data.total_lines
        this.scrollToBottom()
        this.parseTimelineSteps()
      } else {
        this.showEmptyState()
      }
    } catch (error) {
      console.warn("[AgentActivity] pollOnce failed:", error)
      this.showEmptyState()
    }
  }

  async poll() {
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
        
        // Add to all messages and render
        data.messages.forEach(msg => {
          this.allMessages.push(msg)
          this.renderMessage(msg)
        })
        
        this.lastLine = data.total_lines
        this.scrollToBottom()
        
        // Update timeline
        this.parseTimelineSteps()
        
        // Re-apply search if active
        if (this.searchQueryValue && this.searchQueryValue.length >= 2) {
          this.performSearch()
        }
      } else if (this.lastLine === 0) {
        this.hideLoadingState()
        if (data.has_session) {
          this.showWaitingState(data.task_status)
        } else {
          this.showEmptyState()
        }
      }

      if (!this.shouldPoll()) {
        this.stopPolling()
        // Update timeline one more time for completion
        this.parseTimelineSteps()
        return
      }

    } catch (error) {
      console.error('Poll error:', error)
    }

    this.scheduleNextPoll()
  }

  scheduleNextPoll() {
    if (!this.isPolling || this.wsConnected) return
    this.pollTimer = setTimeout(() => this.poll(), this.pollIntervalValue)
  }

  // ========================================
  // MESSAGE RENDERING (enhanced)
  // ========================================

  rerenderAllMessages() {
    if (!this.hasLogTarget) return
    this.logTarget.innerHTML = ''
    this.allMessages.forEach(msg => this.renderMessage(msg))
    this.scrollToBottom()
  }

  renderMessage(msg) {
    const container = this.logTarget
    const div = document.createElement('div')
    div.className = 'agent-log-entry mb-3'
    
    // Determine icon and styling based on content
    const { icon, roleClass, isToolCall } = this.getMessageStyle(msg)
    
    let contentHtml = ''
    let toolCallSummary = ''
    let toolCallContent = ''
    
    if (msg.content && Array.isArray(msg.content)) {
      msg.content.forEach(item => {
        if (item.type === 'text' && item.text) {
          const text = item.text.length > 5000 ? item.text.substring(0, 5000) + '...' : item.text
          contentHtml += `<div class="text-sm text-content whitespace-pre-wrap break-words">${this.escapeHtml(text)}</div>`
        }
        if (item.type === 'thinking' && item.text) {
          const thinking = item.text.length > 1500 ? item.text.substring(0, 1500) + '...' : item.text
          const thinkingIcon = '🧠'
          if (this.compactModeValue) {
            contentHtml += `<div class="text-xs text-purple-400 italic mt-1 cursor-pointer hover:text-purple-300" data-action="click->agent-activity#expandToolCall">${thinkingIcon} Thinking... (click to expand)</div>`
            contentHtml += `<div class="hidden tool-call-content text-xs text-content-muted italic bg-bg-surface/50 rounded px-2 py-1 mt-1">${this.escapeHtml(thinking)}</div>`
          } else {
            contentHtml += `<div class="text-xs text-content-muted italic bg-bg-surface/50 rounded px-2 py-1 mt-1">${thinkingIcon} ${this.escapeHtml(thinking)}</div>`
          }
        }
        if (item.type === 'tool_call') {
          const toolIcon = this.getToolIcon(item.name)
          const toolName = item.name || 'tool'
          toolCallSummary = `<div class="text-xs font-mono text-accent mt-1">${toolIcon} <span class="font-semibold">${this.escapeHtml(toolName)}</span></div>`
        }
        if (item.type === 'tool_result' && item.text) {
          const result = item.text.length > 3000 ? item.text.substring(0, 3000) + '...' : item.text
          
          if (this.compactModeValue) {
            // Compact: show one-liner with expand option
            const preview = result.split('\n')[0].substring(0, 80)
            toolCallContent = `
              <div class="tool-call-entry">
                <div class="flex items-center gap-2 text-xs font-mono text-content-muted mt-1 cursor-pointer hover:text-content-secondary" data-action="click->agent-activity#expandToolCall">
                  <span class="tool-call-chevron transition-transform duration-200">▶</span>
                  <span class="truncate">${this.escapeHtml(preview)}${result.length > 80 ? '...' : ''}</span>
                </div>
                <div class="hidden tool-call-content text-xs font-mono text-content-muted bg-bg-surface rounded px-2 py-1 mt-1 max-h-40 overflow-y-auto whitespace-pre-wrap">${this.escapeHtml(result)}</div>
              </div>
            `
          } else {
            // Expanded: show full content
            toolCallContent = `<div class="text-xs font-mono text-content-muted bg-bg-surface rounded px-2 py-1 mt-1 max-h-40 overflow-y-auto whitespace-pre-wrap">${this.escapeHtml(result)}</div>`
          }
        }
      })
    }
    
    // Build final HTML
    const hasToolContent = toolCallSummary || toolCallContent
    const entryClass = hasToolContent ? 'tool-call-entry' : ''
    
    div.innerHTML = `
      <div class="flex items-start gap-2 p-2 rounded-lg bg-bg-elevated border-l-2 ${roleClass} ${entryClass}">
        <span class="text-sm flex-shrink-0">${icon}</span>
        <div class="flex-1 min-w-0">
          ${contentHtml || ''}
          ${toolCallSummary}
          ${toolCallContent}
          ${!contentHtml && !toolCallSummary && !toolCallContent ? '<span class="text-xs text-content-muted">...</span>' : ''}
        </div>
      </div>
    `
    container.appendChild(div)
  }

  getMessageStyle(msg) {
    let icon = '💬'
    let roleClass = 'border-content-muted'
    let isToolCall = false
    
    if (msg.role === 'user') {
      icon = '👤'
      roleClass = 'border-blue-500'
    } else if (msg.role === 'assistant') {
      icon = '🤖'
      roleClass = 'border-purple-500'
      
      // Check content for specific types
      if (msg.content && Array.isArray(msg.content)) {
        const hasThinking = msg.content.some(c => c.type === 'thinking')
        const hasToolCall = msg.content.some(c => c.type === 'tool_call')
        
        if (hasThinking) {
          icon = '🧠'
          roleClass = 'border-purple-400'
        }
        if (hasToolCall) {
          isToolCall = true
          // Get specific tool icon
          const toolItem = msg.content.find(c => c.type === 'tool_call')
          if (toolItem) {
            icon = this.getToolIcon(toolItem.name)
            roleClass = 'border-amber-500'
          }
        }
      }
    } else if (msg.role === 'toolResult') {
      icon = this.getToolIcon(msg.tool_name)
      roleClass = 'border-green-500'
      isToolCall = true
    }
    
    return { icon, roleClass, isToolCall }
  }

  getToolIcon(toolName) {
    if (!toolName) return '⚙️'
    
    const name = toolName.toLowerCase()
    
    // File operations
    if (name.includes('read') || name === 'file') return '📄'
    if (name.includes('write') || name.includes('edit')) return '✏️'
    
    // Execution
    if (name.includes('exec') || name.includes('shell') || name.includes('process')) return '⚙️'
    
    // Web
    if (name.includes('web_search') || name.includes('search')) return '🔍'
    if (name.includes('web_fetch') || name.includes('fetch') || name.includes('browser')) return '🌐'
    
    // Message/Communication
    if (name.includes('message') || name.includes('send')) return '📨'
    
    // Image
    if (name.includes('image') || name.includes('screenshot')) return '🖼️'
    
    // Nodes/Devices
    if (name.includes('node') || name.includes('camera')) return '📱'
    
    // Canvas
    if (name.includes('canvas')) return '🎨'
    
    // TTS
    if (name.includes('tts') || name.includes('speech')) return '🔊'
    
    return '🔧'
  }

  scrollToBottom() {
    if (this.hasLogTarget) {
      this.logTarget.scrollTop = this.logTarget.scrollHeight
    }
  }

  // ========================================
  // STATE MANAGEMENT
  // ========================================

  showEmptyState() {
    if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.remove('hidden')
    if (this.hasLogTarget) this.logTarget.classList.add('hidden')
    if (this.hasTimelineContainerTarget) this.timelineContainerTarget.classList.add('hidden')
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
    this.allMessages = []
    this.timelineSteps = []
    if (this.hasLogTarget) this.logTarget.innerHTML = ''
    if (this.hasTimelineTarget) this.timelineTarget.innerHTML = ''
    if (this.hasTimelineContainerTarget) this.timelineContainerTarget.classList.add('hidden')
    if (!this.isPolling && !this.wsConnected) this.startPolling()
    else this.poll()
  }
}
