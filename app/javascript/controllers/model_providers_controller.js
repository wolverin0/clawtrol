import { Controller } from "@hotwired/stimulus"

// Model Providers controller — expand/collapse cards and test connectivity.
export default class extends Controller {
  static targets = ["testResult"]

  toggleCard(event) {
    const providerId = event.currentTarget.dataset.providerId
    if (!providerId) return
    const card = document.getElementById(`provider-${providerId}`)
    if (card) card.classList.toggle("hidden")
  }

  async testProvider(event) {
    const btn = event.currentTarget
    const baseUrl = btn.dataset.baseUrl
    const model = btn.dataset.model

    if (!baseUrl || !model) {
      alert("Base URL and model are required for testing")
      return
    }

    btn.disabled = true
    btn.textContent = "⏳ Testing..."

    try {
      const res = await fetch("/model-providers/test", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ base_url: baseUrl, model: model })
      })
      const data = await res.json()

      // Find closest test result area
      const card = btn.closest("[id^='provider-']")
      const resultArea = card ? card.querySelector("[data-model-providers-target='testResult']") : null

      if (resultArea) {
        resultArea.classList.remove("hidden")
        if (data.success) {
          resultArea.innerHTML = `
            <div class="p-3 rounded-lg bg-green-500/10 border border-green-500/30 text-sm">
              <div class="text-green-400 font-medium">✅ Connection successful</div>
              <div class="text-xs text-content-muted mt-1">
                Latency: ${data.latency_ms}ms · Response: "${data.response}"
              </div>
            </div>`
        } else {
          resultArea.innerHTML = `
            <div class="p-3 rounded-lg bg-red-500/10 border border-red-500/30 text-sm">
              <div class="text-red-400 font-medium">❌ Connection failed</div>
              <div class="text-xs text-content-muted mt-1">${data.error || "Unknown error"}</div>
            </div>`
        }
      }
    } catch (e) {
      alert(`Test failed: ${e.message}`)
    } finally {
      btn.disabled = false
      btn.textContent = "🧪 Test Connection"
    }
  }

  _csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
