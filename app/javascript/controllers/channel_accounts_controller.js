import { Controller } from "@hotwired/stimulus"

// Channel Accounts controller — toggle expandable account config cards.
export default class extends Controller {
  toggleCard(event) {
    const accountId = event.currentTarget.dataset.accountId
    if (!accountId) return

    const card = document.getElementById(`card-${accountId}`)
    if (!card) return

    card.classList.toggle("hidden")

    // Toggle arrow direction
    const arrow = event.currentTarget.querySelector("[data-channel-accounts-target='arrow']")
    if (arrow) {
      arrow.textContent = card.classList.contains("hidden") ? "▼" : "▲"
    }
  }
}
