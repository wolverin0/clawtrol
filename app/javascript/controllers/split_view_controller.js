import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { active: Boolean }

  connect() {
    this.activeValue = localStorage.getItem('clawtrol:split-view') === 'true'
    this.updateUI()
  }

  toggle() {
    this.activeValue = !this.activeValue
    localStorage.setItem('clawtrol:split-view', this.activeValue)
    this.updateUI()
  }

  updateUI() {
    const btn = document.getElementById('split-view-toggle')
    if (this.activeValue) {
      document.body.classList.add('split-view-active')
      btn?.classList.add('text-accent', 'bg-accent/10')
    } else {
      document.body.classList.remove('split-view-active')
      btn?.classList.remove('text-accent', 'bg-accent/10')
    }
  }
}
