import { Controller } from "@hotwired/stimulus"

// Manages auto-claim tags in board settings
export default class extends Controller {
  static targets = ["input", "container", "hidden", "options"]
  
  toggle(event) {
    // Show/hide the options section based on toggle state
    if (event.currentTarget.checked) {
      this.optionsTarget.classList.remove("hidden")
    } else {
      this.optionsTarget.classList.add("hidden")
    }
  }
  
  add(event) {
    if (event) event.preventDefault()
    
    const tag = this.inputTarget.value.trim()
    if (!tag) return
    
    // Check if tag already exists
    const existingInputs = this.hiddenTarget.querySelectorAll("input")
    for (const input of existingInputs) {
      if (input.value === tag) {
        this.inputTarget.value = ""
        return
      }
    }
    
    // Add visual tag
    const tagEl = document.createElement("span")
    tagEl.className = "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-accent/20 text-accent auto-claim-tag"
    tagEl.dataset.tag = tag
    tagEl.innerHTML = `${this.escapeHtml(tag)}<button type="button" data-action="click->auto-claim-tags#remove" class="hover:text-accent-hover cursor-pointer"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-3 h-3"><path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" /></svg></button>`
    this.containerTarget.appendChild(tagEl)
    
    // Add hidden input
    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = "board[auto_claim_tags][]"
    hiddenInput.value = tag
    this.hiddenTarget.appendChild(hiddenInput)
    
    this.inputTarget.value = ""
  }
  
  addOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.add()
    }
  }
  
  remove(event) {
    event.preventDefault()
    const tagEl = event.currentTarget.parentElement
    const tag = tagEl.dataset.tag
    
    // Remove visual tag
    tagEl.remove()
    
    // Remove hidden input
    const hiddenInputs = this.hiddenTarget.querySelectorAll("input")
    for (const input of hiddenInputs) {
      if (input.value === tag) {
        input.remove()
        break
      }
    }
  }
  
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
