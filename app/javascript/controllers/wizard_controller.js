import { Controller } from "@hotwired/stimulus"

// Multi-step wizard controller for OpenClaw integration setup
export default class extends Controller {
  static targets = [
    "step", "stepIndicator", "progressBar",
    "prevButton", "nextButton",
    "gatewayUrl", "gatewayToken",
    "agentName", "agentEmoji", "preferredModel",
    "detectStatus", "detectButton",
    "testResults", "testButton",
    "summary"
  ]

  static values = {
    currentStep: { type: Number, default: 1 },
    totalSteps: { type: Number, default: 5 },
    testUrl: String
  }

  connect() {
    this.showStep(this.currentStepValue)
  }

  // Navigation
  next() {
    if (this.currentStepValue < this.totalStepsValue) {
      this.currentStepValue++
      this.showStep(this.currentStepValue)
    }
  }

  prev() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.showStep(this.currentStepValue)
    }
  }

  goToStep(event) {
    const step = parseInt(event.currentTarget.dataset.step)
    if (step >= 1 && step <= this.totalStepsValue) {
      this.currentStepValue = step
      this.showStep(step)
    }
  }

  showStep(step) {
    // Update step visibility
    this.stepTargets.forEach((el, index) => {
      el.classList.toggle("hidden", index + 1 !== step)
    })

    // Update progress bar
    if (this.hasProgressBarTarget) {
      const percent = ((step - 1) / (this.totalStepsValue - 1)) * 100
      this.progressBarTarget.style.width = `${percent}%`
    }

    // Update step indicators
    this.stepIndicatorTargets.forEach((el, index) => {
      const stepNum = index + 1
      const isCurrent = stepNum === step
      const isPast = stepNum < step

      // Reset classes
      el.classList.remove(
        "bg-accent", "text-content", "border-accent",
        "bg-green-500", "border-green-500",
        "bg-bg-elevated", "text-content-muted", "border-border"
      )

      if (isPast) {
        // Completed step
        el.classList.add("bg-green-500", "text-content", "border-green-500")
        el.innerHTML = "✓"
      } else if (isCurrent) {
        // Current step
        el.classList.add("bg-accent", "text-content", "border-accent")
        el.innerHTML = stepNum
      } else {
        // Future step
        el.classList.add("bg-bg-elevated", "text-content-muted", "border-border")
        el.innerHTML = stepNum
      }
    })

    // Update navigation buttons
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.classList.toggle("hidden", step === 1)
    }
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.classList.toggle("hidden", step === this.totalStepsValue)
    }

    // Special handling for step 5 (complete) - show summary
    if (step === 5 && this.hasSummaryTarget) {
      this.updateSummary()
    }
  }

  // Step 1: Auto-detect gateway
  async autoDetect() {
    const url = this.hasGatewayUrlTarget ? this.gatewayUrlTarget.value.trim() : ""
    
    if (!url) {
      this.showDetectStatus("error", "Please enter a Gateway URL")
      return
    }

    this.showDetectStatus("loading", "Checking gateway...")
    
    if (this.hasDetectButtonTarget) {
      this.detectButtonTarget.disabled = true
    }

    try {
      // Try to reach the gateway health endpoint
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 5000)
      
      const response = await fetch(`${url}/health`, {
        method: "GET",
        signal: controller.signal
      })
      
      clearTimeout(timeout)
      
      if (response.ok) {
        this.showDetectStatus("success", "Gateway reachable! ✅")
      } else {
        this.showDetectStatus("error", `Gateway returned status ${response.status}`)
      }
    } catch (error) {
      if (error.name === "AbortError") {
        this.showDetectStatus("error", "Connection timed out")
      } else {
        this.showDetectStatus("error", "Could not reach gateway")
      }
    } finally {
      if (this.hasDetectButtonTarget) {
        this.detectButtonTarget.disabled = false
      }
    }
  }

  showDetectStatus(type, message) {
    if (!this.hasDetectStatusTarget) return

    const statusEl = this.detectStatusTarget
    statusEl.classList.remove("hidden", "text-green-500", "text-red-500", "text-yellow-500")

    switch (type) {
      case "success":
        statusEl.classList.add("text-green-500")
        break
      case "error":
        statusEl.classList.add("text-red-500")
        break
      case "loading":
        statusEl.classList.add("text-yellow-500")
        break
    }

    statusEl.textContent = message
  }

  // Step 4: Test full connection
  async testConnection() {
    if (!this.hasTestResultsTarget) return
    
    if (this.hasTestButtonTarget) {
      this.testButtonTarget.disabled = true
      this.testButtonTarget.textContent = "Testing..."
    }

    this.testResultsTarget.innerHTML = `
      <div class="flex items-center gap-2 text-yellow-500">
        <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Testing connection...</span>
      </div>
    `

    try {
      const response = await fetch(this.testUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      const data = await response.json()
      this.showTestResults(data)
    } catch (error) {
      this.showTestResults({
        gateway_reachable: false,
        token_valid: false,
        webhook_configured: false,
        error: error.message
      })
    } finally {
      if (this.hasTestButtonTarget) {
        this.testButtonTarget.disabled = false
        this.testButtonTarget.textContent = "Test Connection"
      }
    }
  }

  showTestResults(data) {
    if (!this.hasTestResultsTarget) return

    const items = [
      { key: "gateway_reachable", label: "Gateway reachable", step: 1 },
      { key: "token_valid", label: "Token valid", step: 2 },
      { key: "webhook_configured", label: "Webhook configured", step: null }
    ]

    let html = '<div class="space-y-2">'

    items.forEach(item => {
      const success = data[item.key]
      const icon = success ? "✅" : "❌"
      const textClass = success ? "text-green-500" : "text-red-500"
      const stepLink = !success && item.step 
        ? `<button type="button" data-action="click->wizard#goToStep" data-step="${item.step}" class="text-accent hover:underline ml-2 text-xs cursor-pointer">Fix →</button>`
        : ""

      html += `
        <div class="flex items-center gap-2 ${textClass}">
          <span>${icon}</span>
          <span>${item.label}</span>
          ${stepLink}
        </div>
      `
    })

    if (data.error) {
      html += `<div class="text-red-500 text-xs mt-2">Error: ${data.error}</div>`
    }

    if (data.gateway_reachable && data.token_valid && data.webhook_configured) {
      html += `
        <div class="mt-4 p-3 bg-green-500/10 rounded-lg border border-green-500/30">
          <div class="flex items-center gap-2 text-green-500 font-medium">
            <span class="text-xl">🎉</span>
            <span>All checks passed!</span>
          </div>
        </div>
      `
    }

    html += '</div>'
    this.testResultsTarget.innerHTML = html
  }

  // Step 5: Update summary
  updateSummary() {
    if (!this.hasSummaryTarget) return

    const gatewayUrl = this.hasGatewayUrlTarget ? this.gatewayUrlTarget.value : "Not set"
    const agentName = this.hasAgentNameTarget ? this.agentNameTarget.value : "Not set"
    const agentEmoji = this.hasAgentEmojiTarget ? this.agentEmojiTarget.value : "🦞"
    const model = this.hasPreferredModelTarget ? this.preferredModelTarget.selectedOptions[0]?.text : "Default"

    this.summaryTarget.innerHTML = `
      <div class="space-y-3">
        <div class="flex items-center justify-between p-2 bg-bg-elevated rounded">
          <span class="text-content-muted">Gateway</span>
          <span class="text-content font-mono text-xs">${this.escapeHtml(gatewayUrl)}</span>
        </div>
        <div class="flex items-center justify-between p-2 bg-bg-elevated rounded">
          <span class="text-content-muted">Agent</span>
          <span class="text-content">${agentEmoji} ${this.escapeHtml(agentName)}</span>
        </div>
        <div class="flex items-center justify-between p-2 bg-bg-elevated rounded">
          <span class="text-content-muted">Preferred Model</span>
          <span class="text-content">${this.escapeHtml(model)}</span>
        </div>
      </div>
    `
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  // Save form and proceed
  saveAndNext(event) {
    // Let the form submit naturally via Turbo, then advance
    // The form's success will reload the page with saved data
  }
}
