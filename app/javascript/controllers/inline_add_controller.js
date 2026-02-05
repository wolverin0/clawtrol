import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inline-add"
// Handles Trello-style inline card creation with slash commands and templates
export default class extends Controller {
  static targets = ["form", "button", "input", "templateSelect", "hint"]
  static values = {
    status: String,
    url: String,
    templatesUrl: String,
    templates: Array
  }

  connect() {
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.loadTemplates()
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }

  async loadTemplates() {
    try {
      const response = await fetch("/api/v1/task_templates", {
        headers: {
          "Authorization": `Bearer ${this.apiToken}`,
          "Accept": "application/json"
        }
      })
      if (response.ok) {
        this.templatesValue = await response.json()
      }
    } catch (error) {
      console.error("Failed to load templates:", error)
    }
  }

  show() {
    this.buttonTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
    // Add click outside listener after a brief delay to avoid immediate trigger
    setTimeout(() => {
      document.addEventListener("click", this.handleClickOutside)
    }, 0)
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.buttonTarget.classList.remove("hidden")
    this.inputTarget.value = ""
    this.clearHint()
    if (this.hasTemplateSelectTarget) {
      this.templateSelectTarget.value = ""
    }
    document.removeEventListener("click", this.handleClickOutside)
  }

  handleClickOutside(event) {
    // If click is outside the form, cancel
    if (!this.formTarget.contains(event.target)) {
      this.cancel()
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit()
    } else if (event.key === "Escape") {
      this.cancel()
    }
  }

  // Handle input changes to detect slash commands
  handleInput(event) {
    const value = this.inputTarget.value
    const slashMatch = value.match(/^\/(\w+)\s*(.*)/)
    
    if (slashMatch) {
      const [, command, rest] = slashMatch
      const template = this.findTemplate(command)
      
      if (template) {
        this.showHint(`${template.display_name} template`)
        if (this.hasTemplateSelectTarget) {
          this.templateSelectTarget.value = template.slug
        }
      } else {
        this.showHint(`Unknown command: /${command}`, true)
      }
    } else {
      this.clearHint()
      if (this.hasTemplateSelectTarget) {
        this.templateSelectTarget.value = ""
      }
    }
  }

  // Apply template from dropdown
  applyTemplate(event) {
    const slug = event.target.value
    if (!slug) return
    
    const template = this.templatesValue.find(t => t.slug === slug)
    if (!template) return
    
    const currentText = this.inputTarget.value
    // If empty or already has slash command, replace with template prefix
    if (!currentText || currentText.startsWith('/')) {
      this.inputTarget.value = `/${template.slug} `
    }
    this.inputTarget.focus()
    this.showHint(`${template.display_name} template`)
  }

  findTemplate(command) {
    const normalized = command.toLowerCase()
    return this.templatesValue.find(t => 
      t.slug === normalized || 
      t.name.toLowerCase().includes(normalized)
    )
  }

  showHint(message, isError = false) {
    if (this.hasHintTarget) {
      this.hintTarget.textContent = message
      this.hintTarget.classList.remove("hidden", "text-red-500", "text-content-muted")
      this.hintTarget.classList.add(isError ? "text-red-500" : "text-content-muted")
    }
  }

  clearHint() {
    if (this.hasHintTarget) {
      this.hintTarget.classList.add("hidden")
      this.hintTarget.textContent = ""
    }
  }

  async submit() {
    let title = this.inputTarget.value.trim()
    if (!title) return

    // Parse slash command
    let templateSlug = null
    const slashMatch = title.match(/^\/(\w+)\s+(.+)/)
    if (slashMatch) {
      const [, command, taskName] = slashMatch
      const template = this.findTemplate(command)
      if (template) {
        templateSlug = template.slug
        title = taskName.trim()
      }
    }

    // Or use dropdown selection
    if (!templateSlug && this.hasTemplateSelectTarget && this.templateSelectTarget.value) {
      templateSlug = this.templateSelectTarget.value
    }

    try {
      const body = {
        task: {
          title: title,
          status: this.statusValue
        }
      }
      
      if (templateSlug) {
        body.task.template_slug = templateSlug
      }

      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify(body)
      })

      if (response.ok) {
        // Process turbo stream response to add the card and update counts
        const html = await response.text()
        Turbo.renderStreamMessage(html)

        // Clear input but keep form open for rapid entry
        this.inputTarget.value = ""
        this.clearHint()
        if (this.hasTemplateSelectTarget) {
          this.templateSelectTarget.value = ""
        }
        this.inputTarget.focus()
      } else {
        console.error("Failed to create task")
      }
    } catch (error) {
      console.error("Error creating task:", error)
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }

  get apiToken() {
    // Try to get from meta tag or data attribute
    const meta = document.querySelector('meta[name="api-token"]')
    return meta ? meta.content : ""
  }
}
