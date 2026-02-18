import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { taskId: Number, url: String }

  async dispatch(event) {
    event.preventDefault()
    const btn = event.currentTarget
    btn.disabled = true
    btn.textContent = "⏳ Dispatching..."

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      const data = await response.json()
      if (data.success) {
        btn.textContent = "✅ Dispatched!"
        setTimeout(() => location.reload(), 1500)
      } else {
        btn.textContent = `❌ ${data.error}`
        setTimeout(() => { btn.disabled = false; btn.textContent = "🤖 Dispatch to ZeroClaw" }, 3000)
      }
    } catch (e) {
      btn.textContent = "❌ Error"
      setTimeout(() => { btn.disabled = false; btn.textContent = "🤖 Dispatch to ZeroClaw" }, 3000)
    }
  }
}
