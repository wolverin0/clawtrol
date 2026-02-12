import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Handles simple client-side filtering for /analytics.
// We still server-render the page; this controller just updates the query param.
export default class extends Controller {
  static values = { period: String }

  setPeriod(event) {
    const period = event?.params?.period
    if (!period) return

    const url = new URL(window.location.href)
    url.searchParams.set("period", period)
    Turbo.visit(url.toString())
  }
}
