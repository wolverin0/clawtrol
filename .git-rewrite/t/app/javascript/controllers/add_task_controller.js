import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="add-task"
export default class extends Controller {
  static targets = ["input", "icon", "clearButton", "shortcutHint"]
  static values = { url: String, autofocus: { type: Boolean, default: true } }

  // Keywords that trigger priority levels
  static PRIORITY_KEYWORDS = {
    high: ['!!!', 'urgent', 'critical', 'asap', 'immediately'],
    medium: ['!!', 'important', 'soon'],
    low: ['!', 'later', 'someday', 'eventually', 'maybe']
  }

  // Month names for parsing
  static MONTHS = {
    'january': 0, 'jan': 0,
    'february': 1, 'feb': 1,
    'march': 2, 'mar': 2,
    'april': 3, 'apr': 3,
    'may': 4,
    'june': 5, 'jun': 5,
    'july': 6, 'jul': 6,
    'august': 7, 'aug': 7,
    'september': 8, 'sep': 8, 'sept': 8,
    'october': 9, 'oct': 9,
    'november': 10, 'nov': 10,
    'december': 11, 'dec': 11
  }

  // Day names for parsing
  static DAYS = {
    'sunday': 0, 'sun': 0,
    'monday': 1, 'mon': 1,
    'tuesday': 2, 'tue': 2, 'tues': 2,
    'wednesday': 3, 'wed': 3,
    'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4,
    'friday': 5, 'fri': 5,
    'saturday': 6, 'sat': 6
  }

  connect() {
    // Detect platform and show appropriate shortcut
    this.isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
    if (this.hasShortcutHintTarget) {
      const macShortcut = this.shortcutHintTarget.querySelector('.mac-shortcut')
      const winShortcut = this.shortcutHintTarget.querySelector('.win-shortcut')
      if (macShortcut && winShortcut) {
        if (this.isMac) {
          macShortcut.classList.remove('hidden')
          winShortcut.classList.add('hidden')
        } else {
          macShortcut.classList.add('hidden')
          winShortcut.classList.remove('hidden')
        }
      }
    }

    if (this.hasInputTarget && this.autofocusValue) {
      this.inputTarget.focus()
      this.updateState()
      this.onFocus()
    }

    // Global keyboard shortcut: Cmd+K (Mac) or Ctrl+K (Win/Linux) to focus input
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener("keydown", this.handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleGlobalKeydown)
  }

  onFocus() {
    if (this.hasShortcutHintTarget) {
      this.shortcutHintTarget.classList.add("hidden")
    }
  }

  onBlur() {
    // Only show shortcut hint if input is empty
    if (this.hasShortcutHintTarget && this.inputTarget.value.trim().length === 0) {
      this.shortcutHintTarget.classList.remove("hidden")
    }
  }

  handleGlobalKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      if (this.hasInputTarget) {
        this.inputTarget.focus()
        this.inputTarget.select()
      }
    }
  }

  updateState() {
    const hasContent = this.inputTarget.value.trim().length > 0

    if (this.hasIconTarget) {
      if (hasContent) {
        this.iconTarget.classList.remove("text-stone-300", "dark:text-white/30")
        this.iconTarget.classList.add("text-lime-500", "dark:text-lime-500")
      } else {
        this.iconTarget.classList.remove("text-lime-500", "dark:text-lime-500")
        this.iconTarget.classList.add("text-stone-300", "dark:text-white/30")
      }
    }

    if (this.hasClearButtonTarget) {
      if (hasContent) {
        this.clearButtonTarget.classList.remove("hidden")
      } else {
        this.clearButtonTarget.classList.add("hidden")
      }
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.updateState()
    this.inputTarget.focus()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit()
    }

    if (event.key === "Escape") {
      event.preventDefault()
      this.inputTarget.value = ""
      this.updateState()
      this.inputTarget.blur()
    }
  }

  async submit() {
    const input = this.inputTarget.value.trim()
    if (!input) return

    // Detect priority from keywords
    const priority = this.detectPriority(input)

    // Detect due date from natural language
    const { dueDate, cleanedText } = this.detectDueDate(input)

    // Build form data
    const formData = new FormData()
    formData.append("task[name]", cleanedText || input)
    formData.append("task[priority]", priority)
    formData.append("task[enter_pressed]", "true")
    if (dueDate) {
      formData.append("task[due_date]", dueDate)
    }

    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": csrfToken
        },
        body: formData
      })

      if (response.ok) {
        // Clear input on success
        this.inputTarget.value = ""
        this.updateState()
        // Turbo will handle the stream response automatically
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Failed to create task:", error)
    }
  }

  detectPriority(text) {
    const lowerText = text.toLowerCase()
    const keywords = this.constructor.PRIORITY_KEYWORDS

    // Check high first (since !!! contains !! and !)
    if (keywords.high.some(kw => lowerText.includes(kw))) {
      return 3
    }
    if (keywords.medium.some(kw => lowerText.includes(kw))) {
      return 2
    }
    if (keywords.low.some(kw => lowerText.includes(kw))) {
      return 1
    }
    return 0
  }

  detectDueDate(text) {
    const lowerText = text.toLowerCase()
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    let dueDate = null
    let matchedPattern = null

    // Pattern 1: "today"
    if (/\btoday\b/.test(lowerText)) {
      dueDate = new Date(today)
      matchedPattern = /\b(for\s+)?today\b/i
    }
    // Pattern 2: "tomorrow"
    else if (/\btomorrow\b/.test(lowerText)) {
      dueDate = new Date(today)
      dueDate.setDate(dueDate.getDate() + 1)
      matchedPattern = /\b(for\s+)?tomorrow\b/i
    }
    // Pattern 3: "next week"
    else if (/\bnext\s+week\b/.test(lowerText)) {
      dueDate = new Date(today)
      dueDate.setDate(dueDate.getDate() + 7)
      matchedPattern = /\b(for\s+)?next\s+week\b/i
    }
    // Pattern 4: "next [day]" (e.g., "next monday")
    else if (/\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b/.test(lowerText)) {
      const match = lowerText.match(/\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b/)
      if (match) {
        const targetDay = this.constructor.DAYS[match[1]]
        dueDate = this.getNextDayOfWeek(today, targetDay, true)
        matchedPattern = /\b(for\s+)?next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b/i
      }
    }
    // Pattern 5: "on [day]" or just "[day]" (e.g., "on monday", "friday")
    else if (/\b(on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b/.test(lowerText)) {
      const match = lowerText.match(/\b(on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b/)
      if (match) {
        const targetDay = this.constructor.DAYS[match[2]]
        dueDate = this.getNextDayOfWeek(today, targetDay, false)
        matchedPattern = /\b(on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b/i
      }
    }
    // Pattern 6: "in X days/weeks"
    else if (/\bin\s+(\d+)\s+(day|days|week|weeks)\b/.test(lowerText)) {
      const match = lowerText.match(/\bin\s+(\d+)\s+(day|days|week|weeks)\b/)
      if (match) {
        const num = parseInt(match[1])
        const unit = match[2]
        dueDate = new Date(today)
        if (unit.startsWith('week')) {
          dueDate.setDate(dueDate.getDate() + (num * 7))
        } else {
          dueDate.setDate(dueDate.getDate() + num)
        }
        matchedPattern = /\bin\s+\d+\s+(day|days|week|weeks)\b/i
      }
    }
    // Pattern 7: "on [month] [day]" or "[month] [day]" (e.g., "on january 12", "jan 5")
    else if (/\b(on\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\s+(\d{1,2})(st|nd|rd|th)?\b/.test(lowerText)) {
      const match = lowerText.match(/\b(on\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\s+(\d{1,2})(st|nd|rd|th)?\b/)
      if (match) {
        const month = this.constructor.MONTHS[match[2]]
        const day = parseInt(match[3])
        dueDate = new Date(today.getFullYear(), month, day)
        // If the date has passed this year, use next year
        if (dueDate < today) {
          dueDate.setFullYear(dueDate.getFullYear() + 1)
        }
        matchedPattern = /\b(on\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\s+\d{1,2}(st|nd|rd|th)?\b/i
      }
    }
    // Pattern 8: "[day] [month]" (e.g., "12 january", "5th jan")
    else if (/\b(\d{1,2})(st|nd|rd|th)?\s+(of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\b/.test(lowerText)) {
      const match = lowerText.match(/\b(\d{1,2})(st|nd|rd|th)?\s+(of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\b/)
      if (match) {
        const day = parseInt(match[1])
        const month = this.constructor.MONTHS[match[4]]
        dueDate = new Date(today.getFullYear(), month, day)
        // If the date has passed this year, use next year
        if (dueDate < today) {
          dueDate.setFullYear(dueDate.getFullYear() + 1)
        }
        matchedPattern = /\b\d{1,2}(st|nd|rd|th)?\s+(of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\b/i
      }
    }

    // Clean up the text by removing the matched date pattern
    let cleanedText = text
    if (matchedPattern && dueDate) {
      cleanedText = text.replace(matchedPattern, '').replace(/\s+/g, ' ').trim()
    }

    // Format date as YYYY-MM-DD for the form
    const formattedDate = dueDate ? this.formatDate(dueDate) : null

    return { dueDate: formattedDate, cleanedText }
  }

  getNextDayOfWeek(fromDate, targetDay, forceNextWeek = false) {
    const result = new Date(fromDate)
    const currentDay = result.getDay()
    let daysUntil = targetDay - currentDay

    if (daysUntil <= 0 || forceNextWeek) {
      daysUntil += 7
    }

    result.setDate(result.getDate() + daysUntil)
    return result
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}
