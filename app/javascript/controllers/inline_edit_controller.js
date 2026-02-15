import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "input"]

  edit(event) {
    event.preventDefault()
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  save(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  cancel(event) {
    event.preventDefault()
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }
}
