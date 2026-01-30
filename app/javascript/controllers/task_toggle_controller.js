import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Connects to data-controller="task-toggle"
export default class extends Controller {
  static targets = ["form", "checkbox", "card"]
  static values = {
    completed: Boolean,
    originalPosition: Number
  }

  connect() {
    this._handleExternalToggle = (event) => {
      const { taskId, completed } = event.detail || {}
      const li = this.cardTarget.closest('li')
      if (!li) return
      if (String(taskId) !== String(li.dataset.taskId)) return

      // Update UI and animate without submitting (already saved by modal)
      this.updateUIImmediate(completed)
      this.animateMove(completed) // Animate even if external
      this.completedValue = completed
      this.updateProgressBar()
      this.updateTaskCounts(this.getTaskListId(li)) // Pass taskListId
    }

    window.addEventListener('task:externallyToggled', this._handleExternalToggle)
  }

  disconnect() {
    window.removeEventListener('task:externallyToggled', this._handleExternalToggle)
  }

  async toggle(event) {
    // Prevent the click from bubbling up to the card (which would trigger edit mode)
    event.stopPropagation()
    event.preventDefault()

    // Disable pointer events during animation
    this.cardTarget.style.pointerEvents = "none"

    // Get the current state
    const willBeCompleted = !this.completedValue

    // Store task list ID before animation moves the element
    const taskElement = this.cardTarget.closest('li')
    const taskListId = this.getTaskListId(taskElement)

    // Update UI immediately
    this.updateUIImmediate(willBeCompleted)

    // Animate the move
    await this.animateMove(willBeCompleted)

    // Submit to the server (Turbo Streams will handle DOM updates)
    await this.submitToggle()

    // Update the completed value so future toggles work correctly
    this.completedValue = willBeCompleted

    // If we just completed a task, store the original position
    // If we just uncompleted, clear it
    if (willBeCompleted) {
      // When completing, save the current position as original_position
      const currentPosition = parseInt(taskElement.dataset.taskPosition)
      this.originalPositionValue = currentPosition
    } else {
      // When uncompleting, clear original_position
      this.originalPositionValue = null
      taskElement.removeAttribute('data-task-toggle-original-position-value')
    }

    // Re-enable pointer events
    this.cardTarget.style.pointerEvents = ""

    // Update progress bar and counts
    this.updateProgressBar()
    this.updateTaskCounts(taskListId) // Pass taskListId
  }

  updateProgressBar() {
    // Count all tasks from all task lists
    const incompleteTasks = document.querySelectorAll('[id^="task-list-"] [data-task-id]')
    const completedSections = document.querySelectorAll('[id^="completed-tasks-"]')
    let completedTasks = []
    completedSections.forEach(section => {
      completedTasks = completedTasks.concat(Array.from(section.querySelectorAll('[data-task-id]')))
    })

    const totalTasks = incompleteTasks.length + completedTasks.length

    // Dispatch custom event for progress bar to listen to
    window.dispatchEvent(new CustomEvent('task:toggled', {
      detail: { totalTasks, completedTasks: completedTasks.length }
    }))
  }

  updateUIImmediate(willBeCompleted) {
    const checkbox = this.checkboxTarget
    const card = this.cardTarget

    if (willBeCompleted) {
      card.classList.remove('bg-stone-50', 'hover:bg-stone-100', 'dark:bg-white/10', 'dark:hover:bg-white/20')
      card.classList.add('bg-stone-50', 'hover:bg-stone-100', 'dark:bg-white/10', 'dark:hover:bg-white/20')

      checkbox.classList.remove('border-stone-300', 'dark:border-white/50', 'bg-white', 'dark:bg-transparent')
      checkbox.classList.add('bg-white', 'dark:bg-white/20', 'border-lime-500', 'dark:border-lime-500', 'hover:border-red-500/70', 'dark:hover:border-red-500/70')

      checkbox.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="w-2.5 h-2.5 text-lime-500 dark:text-lime-500">
          <polyline points="20 6 9 17 4 12"></polyline>
        </svg>
      `
    } else {
      card.classList.remove('bg-stone-50', 'hover:bg-stone-100', 'dark:bg-white/10', 'dark:hover:bg-white/20')
      card.classList.add('bg-stone-50', 'hover:bg-stone-100', 'dark:bg-white/10', 'dark:hover:bg-white/20')

      checkbox.classList.remove('bg-white', 'dark:bg-white/20', 'border-lime-500', 'dark:border-lime-500', 'hover:border-red-500/70', 'dark:hover:border-red-500/70')
      checkbox.classList.add('bg-white', 'dark:bg-transparent', 'border-stone-300', 'dark:border-white/50')

      checkbox.innerHTML = ''
    }
  }

  async animateMove(willBeCompleted) {
    const taskElement = this.cardTarget.closest('li')
    
    // Just fade out the task from its current location
    taskElement.classList.add('task-fading')
    await new Promise(resolve => setTimeout(resolve, 200))
    
    // Remove the task - Turbo Streams will add it back to the correct list
    taskElement.remove()
  }

  getTaskListId(taskElement) {
    // Find the task list container by looking up the DOM tree
    const taskListContainer = taskElement.closest('[id^="task_list_"]')
    if (taskListContainer) {
      return taskListContainer.id.replace('task_list_', '')
    }
    // Fallback: try to get from a wrapper element
    const wrapper = taskElement.closest('[id^="task-list-"]')
    if (wrapper) {
      return wrapper.id.match(/task-list-(\d+)/)?.[1]
    }
    return null
  }

  updateTaskCounts(taskListId) {
    if (!taskListId) return

    const incompleteList = document.querySelector(`#task-list-${taskListId}-tasks`)
    const completedList = document.querySelector(`#completed-tasks-${taskListId}`)

    const incompleteCount = incompleteList ? incompleteList.querySelectorAll('[data-task-id]').length : 0
    const completedCount = completedList ? completedList.querySelectorAll('[data-task-id]').length : 0

    const totalCount = incompleteCount + completedCount

    const progressBar = document.querySelector(`#progress-bar-${taskListId}`)
    if (progressBar) {
      const percentage = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0
      progressBar.style.width = `${percentage}%`
    }

    const completedSection = document.querySelector(`#completed-section-${taskListId}`)
    if (completedSection) {
      // Show/hide completed section based on whether there are completed tasks
      if (completedCount > 0) {
        completedSection.classList.remove('hidden')
      } else {
        completedSection.classList.add('hidden')
      }
    }
  }

  async submitToggle() {
    const formData = new FormData(this.formTarget)

    try {
      const response = await fetch(this.formTarget.action, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector("[name='csrf-token']").content,
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: formData
      })

      if (!response.ok) {
        console.error('Failed to toggle task')
      } else {
        // Handle Turbo Stream response
        const html = await response.text()
        if (html) {
          Turbo.renderStreamMessage(html)
        }
      }
    } catch (error) {
      console.error('Error toggling task:', error)
    }
  }
}
