import { Controller } from "@hotwired/stimulus"
import { consumer } from "channels"

/**
 * AgentChatController
 *
 * Stimulus controller for live chat with a running agent session.
 * Connects to ChatChannel via ActionCable and renders messages as chat bubbles.
 *
 * Values:
 *   task-id      — the task ID to subscribe to
 *   board-id     — the board ID (for history endpoint)
 *   session-id   — the agent_session_id (presence check)
 *
 * Targets:
 *   messages     — container for chat bubbles
 *   input        — text input field
 *   sendButton   — submit button
 *   thinking     — "thinking..." indicator
 *   empty        — empty state message
 *   status       — connection status indicator
 */
export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "thinking", "empty", "status"]
  static values = {
    taskId: Number,
    boardId: Number,
    sessionId: String
  }

  connect() {
    this.messageIds = new Set()
    this.waitingForResponse = false

    if (!this.sessionIdValue) {
      this.showStatus("No agent session", "disconnected")
      return
    }

    this.loadHistory()
    this.subscribe()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  // Subscribe to ChatChannel via ActionCable
  subscribe() {
    this.subscription = consumer.subscriptions.create(
      { channel: "ChatChannel", task_id: this.taskIdValue },
      {
        connected: () => {
          console.log(`[AgentChat] Connected to task ${this.taskIdValue}`)
          this.showStatus("Connected", "connected")
        },
        disconnected: () => {
          console.log(`[AgentChat] Disconnected from task ${this.taskIdValue}`)
          this.showStatus("Disconnected", "disconnected")
        },
        received: (data) => {
          this.handleReceived(data)
        }
      }
    )
  }

  // Handle incoming data from the channel
  handleReceived(data) {
    if (data.type === "message") {
      this.appendMessage(data.role, data.content, data.timestamp)
      if (data.role === "agent") {
        this.hideThinking()
        this.waitingForResponse = false
      }
    } else if (data.type === "status") {
      if (data.status === "error") {
        this.appendSystemMessage(`Error: ${data.detail || "Unknown error"}`)
        this.hideThinking()
        this.waitingForResponse = false
      }
    }
  }

  // Load chat history from the server
  async loadHistory() {
    try {
      const url = `/boards/${this.boardIdValue}/tasks/${this.taskIdValue}/chat_history`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      const messages = data.messages || []

      if (messages.length === 0) {
        this.showEmpty()
        return
      }

      this.hideEmpty()
      messages.forEach((msg) => {
        const role = msg.role || (msg.from === "user" ? "user" : "agent")
        const content = msg.content || msg.text || msg.message || ""
        const ts = msg.timestamp || msg.created_at
        if (content.trim()) {
          this.appendMessage(role, content, ts, true)
        }
      })
      this.scrollToBottom()
    } catch (e) {
      console.warn("[AgentChat] Could not load history:", e)
    }
  }

  // Send message when button clicked or enter pressed
  send(event) {
    event?.preventDefault()
    const input = this.inputTarget
    const message = input.value.trim()
    if (!message) return

    // Clear input
    input.value = ""
    input.focus()

    // Send via ActionCable
    if (this.subscription) {
      this.subscription.send({ message })
      this.showThinking()
      this.waitingForResponse = true
    }
  }

  // Handle keydown on input — send on Enter, allow Shift+Enter for newlines
  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.send()
    }
  }

  // Append a chat message bubble
  appendMessage(role, content, timestamp, isHistory = false) {
    // Deduplicate by content+timestamp
    const msgKey = `${role}:${content}:${timestamp}`
    if (this.messageIds.has(msgKey) && !isHistory) return
    this.messageIds.add(msgKey)

    this.hideEmpty()

    const container = this.messagesTarget
    const wrapper = document.createElement("div")
    wrapper.classList.add("flex", "mb-3", "animate-fade-in")

    if (role === "user") {
      wrapper.classList.add("justify-end")
      wrapper.innerHTML = `
        <div class="max-w-[80%] rounded-2xl rounded-br-md px-4 py-2.5 bg-accent/20 text-accent border border-accent/20">
          <div class="text-sm whitespace-pre-wrap break-words">${this.escapeHtml(content)}</div>
          ${timestamp ? `<div class="text-[10px] text-accent/50 mt-1 text-right">${this.formatTime(timestamp)}</div>` : ""}
        </div>
      `
    } else if (role === "agent") {
      wrapper.innerHTML = `
        <div class="max-w-[80%] rounded-2xl rounded-bl-md px-4 py-2.5 bg-bg-elevated text-content-secondary border border-border">
          <div class="text-sm whitespace-pre-wrap break-words">${this.escapeHtml(content)}</div>
          ${timestamp ? `<div class="text-[10px] text-content-muted mt-1">${this.formatTime(timestamp)}</div>` : ""}
        </div>
      `
    } else {
      // system messages
      wrapper.classList.add("justify-center")
      wrapper.innerHTML = `
        <div class="text-[11px] text-content-muted italic px-3 py-1">${this.escapeHtml(content)}</div>
      `
    }

    container.appendChild(wrapper)
    if (!isHistory) this.scrollToBottom()
  }

  // Append a system-level message (errors, etc.)
  appendSystemMessage(text) {
    this.appendMessage("system", text, null)
  }

  // Show the "thinking..." indicator
  showThinking() {
    if (this.hasThinkingTarget) {
      this.thinkingTarget.classList.remove("hidden")
      this.scrollToBottom()
    }
  }

  // Hide the "thinking..." indicator
  hideThinking() {
    if (this.hasThinkingTarget) {
      this.thinkingTarget.classList.add("hidden")
    }
  }

  showEmpty() {
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
  }

  hideEmpty() {
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
  }

  showStatus(text, state) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      this.statusTarget.className = `text-[10px] font-medium px-1.5 py-0.5 rounded ${
        state === "connected"
          ? "bg-green-500/20 text-green-400"
          : "bg-red-500/20 text-red-400"
      }`
    }
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      const el = this.messagesTarget
      el.scrollTop = el.scrollHeight
    })
  }

  formatTime(ts) {
    if (!ts) return ""
    try {
      const date = typeof ts === "number" ? new Date(ts * 1000) : new Date(ts)
      return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    } catch {
      return ""
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
