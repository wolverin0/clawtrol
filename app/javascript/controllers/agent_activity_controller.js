import { Controller } from "@hotwired/stimulus"
import { subscribeToAgentActivity } from "channels"

// ========================================
// TOOL COLOR PALETTE (PinchChat-inspired)
// ========================================
const TOOL_COLORS = {
  exec:          { r: 245, g: 158, b: 11 },   // amber
  web_search:    { r: 16,  g: 185, b: 129 },   // emerald
  web_fetch:     { r: 16,  g: 185, b: 129 },   // emerald
  Read:          { r: 14,  g: 165, b: 233 },   // sky
  read:          { r: 14,  g: 165, b: 233 },   // sky
  Write:         { r: 139, g: 92,  b: 246 },   // violet
  write:         { r: 139, g: 92,  b: 246 },   // violet
  Edit:          { r: 139, g: 92,  b: 246 },   // violet
  edit:          { r: 139, g: 92,  b: 246 },   // violet
  browser:       { r: 6,   g: 182, b: 212 },   // cyan
  image:         { r: 236, g: 72,  b: 153 },   // pink
  message:       { r: 99,  g: 102, b: 241 },   // indigo
  memory_recall: { r: 244, g: 63,  b: 94  },   // rose
  cron:          { r: 249, g: 115, b: 22  },   // orange
  sessions_spawn:{ r: 20,  g: 184, b: 166 },   // teal
}
const DEFAULT_RGB = { r: 161, g: 161, b: 170 } // zinc

/**
 * Agent Activity Controller - Enhanced terminal view with filtering, search, and timeline
 * 
 * Features:
 * - Smart filtering: Tool calls collapsed by default, expandable
 * - Progress indicators with meaningful icons
 * - Mini timeline showing agent steps
 * - In-terminal search (Ctrl+F)
 * - PinchChat-inspired colored tool badges
 * - Collapsible thinking blocks
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
  // PINCHCHAT-INSPIRED TOGGLE METHODS
  // ========================================

  toggleToolCall(event) {
    const btn = event.currentTarget
    const panel = btn.nextElementSibling
    if (!panel) return
    panel.classList.toggle('hidden')
  }

  toggleThinking(event) {
    const btn = event.currentTarget
    const content = btn.nextElementSibling
    const chevron = btn.querySelector('.thinking-chevron')
    content.classList.toggle('hidden')
    chevron.style.transform = content.classList.contains('hidden') ? '' : 'rotate(90deg)'
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
          this.handleWebSocketMessage(data)
        }
      })
    } catch (error) {
      console.warn("[AgentActivity] WebSocket connection failed:", error)
    }
  }

  // Handle incoming WebSocket messages
  handleWebSocketMessage(data) {
    if (data.type === "activity" && data.messages && data.messages.length > 0) {
      console.log(`[AgentActivity] Streaming ${data.messages.length} messages via WebSocket`)
      
      this.hideEmptyState()
      this.hideLoadingState()
      
      data.messages.forEach(msg => {
        this.allMessages.push(msg)
        this.renderMessage(msg)
      })
      
      if (data.total_lines) {
        this.lastLine = data.total_lines
      }
      
      this.scrollToBottom()
      this.parseTimelineSteps()
      
      if (this.searchQueryValue && this.searchQueryValue.length >= 2) {
        this.performSearch()
      }
    } else if (data.type === "agent_event") {
      console.log("[AgentActivity] agent_event push received — triggering poll")
      this.poll()
    } else if (data.type === "activity") {
      this.poll()
    } else if (data.type === "status") {
      if (data.status) {
        this.taskStatusValue = data.status
        this.updateStatusBadge(data.status)
      }
      
      if (data.session_linked) {
        this.poll()
      }
      
      if (!this.shouldPoll()) {
        this.stopPolling()
        this.parseTimelineSteps()
      }
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

      if (!data.has_session && !(data.persisted_count > 0)) {
        this.showEmptyState()
        this.stopPolling()
        return
      }

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
  // MESSAGE RENDERING (PinchChat-enhanced)
  // ========================================

  rerenderAllMessages() {
    if (!this.hasLogTarget) return
    this.logTarget.innerHTML = ''
    this.allMessages.forEach(msg => this.renderMessage(msg))
    this.scrollToBottom()
  }

  // Get color for a tool name
  getToolColor(toolName) {
    if (!toolName) return DEFAULT_RGB
    return TOOL_COLORS[toolName] || DEFAULT_RGB
  }

  // Get emoji for tool
  getToolEmoji(toolName) {
    if (!toolName) return '⚙️'
    const name = toolName.toLowerCase()
    if (name === 'exec') return '⚡'
    if (name.includes('read') || name === 'file') return '📄'
    if (name.includes('write')) return '✏️'
    if (name.includes('edit')) return '✏️'
    if (name.includes('web_search') || name.includes('search')) return '🔍'
    if (name.includes('web_fetch') || name.includes('fetch')) return '🌐'
    if (name === 'browser') return '🌐'
    if (name.includes('message') || name.includes('send')) return '📨'
    if (name.includes('image') || name.includes('screenshot')) return '🖼️'
    if (name.includes('memory')) return '💾'
    if (name.includes('cron')) return '⏰'
    if (name.includes('sessions_spawn') || name.includes('spawn')) return '🤖'
    if (name.includes('node') || name.includes('camera')) return '📱'
    if (name.includes('canvas')) return '🎨'
    if (name.includes('tts') || name.includes('speech')) return '🔊'
    return '🔧'
  }

  // Get context hint for a tool (PinchChat getContextHint)
  getContextHint(toolName, input) {
    if (!input || !toolName) return ''
    const name = toolName.toLowerCase()
    try {
      const params = typeof input === 'string' ? JSON.parse(input) : input
      if (name === 'exec') return (params.command || '').substring(0, 60)
      if (['read', 'write', 'edit', 'Read', 'Write', 'Edit'].includes(toolName)) {
        return params.file_path || params.path || ''
      }
      if (name === 'web_search') return (params.query || '').substring(0, 50)
      if (name === 'web_fetch') return (params.url || '').substring(0, 60)
      if (name === 'browser') return params.action || ''
      if (name === 'sessions_spawn') return (params.task || '').substring(0, 50)
    } catch (e) {
      // ignore parse errors
    }
    return ''
  }

  // Render a colored tool badge (PinchChat ToolCall-inspired)
  renderToolBadge(toolName, input, result) {
    const { r, g, b } = this.getToolColor(toolName)
    const emoji = this.getToolEmoji(toolName)
    const hint = this.getContextHint(toolName, input)
    const hintHtml = hint ? ` <span class="opacity-60 font-normal truncate max-w-[200px] inline-block align-bottom">${this.escapeHtml(hint)}</span>` : ''

    const inputJson = typeof input === 'string' ? input : JSON.stringify(input, null, 2)
    const resultText = result ? (result.length > 3000 ? result.substring(0, 3000) + '...' : result) : '(no result)'

    return `
      <div class="my-0.5">
        <button 
          class="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-mono font-semibold cursor-pointer hover:brightness-125 transition-all"
          style="border-color: rgba(${r},${g},${b},0.3); background: rgba(${r},${g},${b},0.10); color: rgb(${r},${g},${b})"
          data-action="click->agent-activity#toggleToolCall"
          data-r="${r}" data-g="${g}" data-b="${b}"
        >${emoji} ${this.escapeHtml(toolName)}${hintHtml}</button>
        <div class="hidden mt-1 rounded-xl border p-2 text-xs font-mono" style="border-color: rgba(${r},${g},${b},0.2); background: rgba(${r},${g},${b},0.05)">
          <div class="text-[11px] opacity-70 mb-1">Parameters</div>
          <pre class="whitespace-pre-wrap break-words max-h-48 overflow-y-auto bg-black/20 rounded p-2">${this.escapeHtml(inputJson)}</pre>
          <div class="text-[11px] opacity-70 mb-1 mt-2">Result</div>
          <pre class="whitespace-pre-wrap break-words max-h-48 overflow-y-auto bg-black/20 rounded p-2">${this.escapeHtml(resultText)}</pre>
        </div>
      </div>
    `
  }

  renderMessage(msg) {
    const container = this.logTarget
    const div = document.createElement('div')
    div.className = 'agent-log-entry mb-3'
    
    const { icon, roleClass, isToolCall } = this.getMessageStyle(msg)
    
    let contentHtml = ''
    
    // We need to pair tool_calls with their results - collect them first
    const toolCallMap = {}  // name -> { input, result }
    
    if (msg.content && Array.isArray(msg.content)) {
      // First pass: collect tool results
      msg.content.forEach(item => {
        if (item.type === 'tool_result' && item.tool_call_id) {
          toolCallMap[item.tool_call_id] = { result: item.text || '' }
        }
      })

      // Second pass: render items
      msg.content.forEach(item => {
        if (item.type === 'text' && item.text) {
          const text = item.text.length > 5000 ? item.text.substring(0, 5000) + '...' : item.text
          contentHtml += `<div class="text-sm text-content whitespace-pre-wrap break-words">${this.escapeHtml(text)}</div>`
        }

        if (item.type === 'thinking' && item.text) {
          // PinchChat-style thinking block
          const thinking = item.text.length > 1500 ? item.text.substring(0, 1500) + '...' : item.text
          contentHtml += `
            <div class="my-1">
              <button class="inline-flex items-center gap-1.5 rounded-full border border-purple-500/30 bg-purple-500/10 px-2.5 py-1 text-xs text-purple-300 hover:brightness-125 transition-all cursor-pointer"
                      data-action="click->agent-activity#toggleThinking">
                🧠 <span class="font-medium">Thinking</span> <span class="thinking-chevron transition-transform duration-200">▶</span>
              </button>
              <div class="thinking-content hidden mt-1 rounded-xl border border-purple-500/20 bg-purple-500/5 p-2 text-xs italic text-content-muted whitespace-pre-wrap max-h-64 overflow-y-auto">${this.escapeHtml(thinking)}</div>
            </div>
          `
        }

        if (item.type === 'tool_call') {
          // PinchChat-style colored badge
          const toolName = item.name || 'tool'
          const input = item.input || item.params || {}
          // Look for result by tool_use_id
          const resultData = toolCallMap[item.id] || {}
          const result = resultData.result || ''
          contentHtml += this.renderToolBadge(toolName, input, result)
        }

        if (item.type === 'tool_result' && !item.tool_call_id) {
          // Standalone tool result (toolResult role messages)
          const result = item.text || ''
          const trimmedResult = result.length > 3000 ? result.substring(0, 3000) + '...' : result
          const toolName = msg.tool_name || 'result'
          contentHtml += this.renderToolBadge(toolName, {}, trimmedResult)
        }
      })
    }

    // For toolResult role messages (legacy format)
    if (msg.role === 'toolResult' && !contentHtml) {
      const toolName = msg.tool_name || 'result'
      const result = (msg.content && typeof msg.content === 'string') ? msg.content : 
                     (msg.content && Array.isArray(msg.content) ? msg.content.map(c => c.text || '').join('') : '')
      const trimmedResult = result.length > 3000 ? result.substring(0, 3000) + '...' : result
      contentHtml += this.renderToolBadge(toolName, {}, trimmedResult)
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
      
      if (msg.content && Array.isArray(msg.content)) {
        const hasThinking = msg.content.some(c => c.type === 'thinking')
        const hasToolCall = msg.content.some(c => c.type === 'tool_call')
        
        if (hasThinking) {
          icon = '🧠'
          roleClass = 'border-purple-400'
        }
        if (hasToolCall) {
          isToolCall = true
          const toolItem = msg.content.find(c => c.type === 'tool_call')
          if (toolItem) {
            icon = this.getToolEmoji(toolItem.name)
            roleClass = 'border-amber-500'
          }
        }
      }
    } else if (msg.role === 'toolResult') {
      icon = this.getToolEmoji(msg.tool_name)
      roleClass = 'border-green-500'
      isToolCall = true
    }
    
    return { icon, roleClass, isToolCall }
  }

  getToolIcon(toolName) {
    return this.getToolEmoji(toolName)
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
    div.textContent = String(text)
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
