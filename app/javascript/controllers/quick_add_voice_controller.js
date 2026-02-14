import { Controller } from "@hotwired/stimulus"

// Quick Add Voice Controller — Web Speech API for voice-to-text task titles
// Also provides client-side auto-tag preview based on keywords.
export default class extends Controller {
  static targets = ["input", "micButton", "micIcon", "status", "tagPreview", "tagList"]

  connect() {
    this.recording = false
    this.recognition = null

    // Check for Web Speech API support
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (SpeechRecognition) {
      this.recognition = new SpeechRecognition()
      this.recognition.continuous = false
      this.recognition.interimResults = true
      this.recognition.lang = "es-AR" // Default to Spanish (Argentina)
      this.recognition.maxAlternatives = 1

      this.recognition.onresult = (event) => this.onResult(event)
      this.recognition.onerror = (event) => this.onError(event)
      this.recognition.onend = () => this.onEnd()

      // Show mic button
      this.micButtonTarget.classList.remove("hidden")
    }

    // Auto-tag on input change
    this.inputTarget.addEventListener("input", () => this.updateTagPreview())
  }

  disconnect() {
    if (this.recording && this.recognition) {
      this.recognition.stop()
    }
  }

  toggleRecording() {
    if (this.recording) {
      this.recognition.stop()
    } else {
      this.startRecording()
    }
  }

  startRecording() {
    try {
      this.recognition.start()
      this.recording = true
      this.micIconTarget.textContent = "🔴"
      this.micButtonTarget.classList.add("border-red-500", "text-red-400")
      this.statusTarget.textContent = "Listening..."
      this.statusTarget.classList.remove("hidden")
    } catch (e) {
      console.error("Speech recognition start failed:", e)
      this.statusTarget.textContent = "Failed to start. Try again."
      this.statusTarget.classList.remove("hidden")
    }
  }

  onResult(event) {
    const results = event.results
    const last = results[results.length - 1]
    const transcript = last[0].transcript

    if (last.isFinal) {
      // Append to existing input (allows multiple recordings)
      const existing = this.inputTarget.value.trim()
      this.inputTarget.value = existing ? `${existing} ${transcript}` : transcript
    } else {
      // Show interim results in status
      this.statusTarget.textContent = `🎤 ${transcript}`
    }

    this.updateTagPreview()
  }

  onError(event) {
    console.warn("Speech recognition error:", event.error)
    this.recording = false
    this.micIconTarget.textContent = "🎤"
    this.micButtonTarget.classList.remove("border-red-500", "text-red-400")

    const messages = {
      "no-speech": "No speech detected",
      "audio-capture": "No microphone found",
      "not-allowed": "Microphone access denied"
    }
    this.statusTarget.textContent = messages[event.error] || `Error: ${event.error}`
    setTimeout(() => this.statusTarget.classList.add("hidden"), 3000)
  }

  onEnd() {
    this.recording = false
    this.micIconTarget.textContent = "🎤"
    this.micButtonTarget.classList.remove("border-red-500", "text-red-400")
    this.statusTarget.classList.add("hidden")
  }

  updateTagPreview() {
    const text = this.inputTarget.value.toLowerCase()
    if (!text.trim()) {
      this.tagPreviewTarget.classList.add("hidden")
      return
    }

    const rules = {
      "bug": ["bug", "fix"],
      "fix": ["bug", "fix"],
      "security": ["security"],
      "xss": ["security", "xss"],
      "sql": ["security", "sql"],
      "test": ["testing"],
      "refactor": ["code-quality", "refactor"],
      "performance": ["performance"],
      "slow": ["performance"],
      "n+1": ["performance"],
      "ui": ["frontend", "ui"],
      "css": ["frontend", "css"],
      "responsive": ["frontend", "responsive"],
      "api": ["backend", "api"],
      "deploy": ["infrastructure", "deploy"],
      "docker": ["infrastructure", "docker"],
      "research": ["research"],
      "mikrotik": ["network", "mikrotik"],
      "unifi": ["network", "unifi"]
    }

    const tags = new Set()
    for (const [keyword, tagList] of Object.entries(rules)) {
      if (text.includes(keyword)) {
        tagList.forEach(t => tags.add(t))
      }
    }

    if (tags.size === 0) {
      this.tagPreviewTarget.classList.add("hidden")
      return
    }

    this.tagPreviewTarget.classList.remove("hidden")
    this.tagListTarget.innerHTML = Array.from(tags).map(tag =>
      `<span class="px-2 py-0.5 text-xs rounded-full bg-accent/20 text-accent border border-accent/30">${tag}</span>`
    ).join("")
  }
}
