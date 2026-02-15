import { Controller } from "@hotwired/stimulus"

// DM Policy & Pairing Manager controller.
// Handles approve/reject pairing actions via AJAX.
export default class extends Controller {
  async approvePairing(event) {
    const pairingId = event.currentTarget.dataset.pairingId
    if (!pairingId) return

    try {
      const res = await fetch("/dm-policy/approve-pairing", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ pairing_id: pairingId })
      })
      const data = await res.json()

      if (data.error) {
        alert(`Failed: ${data.error}`)
      } else {
        const el = document.getElementById(`pairing-${pairingId}`)
        if (el) {
          el.innerHTML = '<div class="text-center py-2 text-green-400 text-sm">✅ Approved</div>'
          setTimeout(() => el.remove(), 2000)
        }
      }
    } catch (e) {
      alert(`Error: ${e.message}`)
    }
  }

  async rejectPairing(event) {
    const pairingId = event.currentTarget.dataset.pairingId
    if (!pairingId) return

    try {
      const res = await fetch("/dm-policy/reject-pairing", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ pairing_id: pairingId })
      })
      const data = await res.json()

      if (data.error) {
        alert(`Failed: ${data.error}`)
      } else {
        const el = document.getElementById(`pairing-${pairingId}`)
        if (el) {
          el.innerHTML = '<div class="text-center py-2 text-red-400 text-sm">❌ Rejected</div>'
          setTimeout(() => el.remove(), 2000)
        }
      }
    } catch (e) {
      alert(`Error: ${e.message}`)
    }
  }

  _csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
