import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="sortable"
export default class extends Controller {
  static targets = ["list", "plusTrashBox", "plusButton", "trashBox"]
  static values = {
    projectId: Number,
    inbox: Boolean,
    today: Boolean
  }

  connect() {
    if (!this.hasListTarget) return

    this.sortable = Sortable.create(this.listTarget, {
      animation: 150,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      delay: 150,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      filter: '[style*="display: none"]', // Don't allow dragging hidden (filtered) items
      onStart: this.start.bind(this),
      onEnd: this.end.bind(this),
      onMove: this.move.bind(this)
    })

    // Track hover state
    this.isOverTrash = false

    // Add event listeners for trash hover
    if (this.hasTrashBoxTarget) {
      this.trashBoxTarget.addEventListener("dragenter", this.handleTrashEnter.bind(this))
      this.trashBoxTarget.addEventListener("dragleave", this.handleTrashLeave.bind(this))
    }
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  start(event) {
    // Store the dragged task ID and element
    this.draggedTaskId = event.item.dataset.taskId
    this.draggedElement = event.item

    // Show trash box (with or without plus button)
    if (this.hasTrashBoxTarget && this.hasPlusTrashBoxTarget) {
      if (this.hasPlusButtonTarget) {
        this.plusButtonTarget.classList.add("hidden")
      }
      this.plusTrashBoxTarget.classList.remove("hidden")
      this.trashBoxTarget.classList.remove("hidden")
      this.trashBoxTarget.classList.add("flex")
      this.plusTrashBoxTarget.classList.remove("h-12")
      this.plusTrashBoxTarget.classList.add("h-24")
    }

    // Mark sidebar projects as drop targets
    this.setupSidebarDropTargets()
  }

  setupSidebarDropTargets() {
    const projects = document.querySelectorAll('.sidebar-project[data-project-id]')
    const inbox = document.querySelector('.sidebar-inbox')
    this.sidebarProjectHandlers = []

    // Helper to clear all highlights
    const today = document.querySelector('.sidebar-today')
    const clearAllHighlights = () => {
      projects.forEach(p => {
        p.style.transform = ''
        p.style.boxShadow = ''
      })
      if (inbox) {
        inbox.style.transform = ''
        inbox.style.boxShadow = ''
      }
      if (today) {
        today.style.transform = ''
        today.style.boxShadow = ''
      }
    }

    // Setup project drop targets
    projects.forEach(el => {
      el.classList.add('drop-target')
      const projectId = parseInt(el.dataset.projectId, 10)
      const isCurrent = projectId === this.projectIdValue
      if (isCurrent) {
        el.classList.add('current-project')
      }

      let dragCounter = 0

      const enterHandler = (e) => {
        if (!this.draggedTaskId) return
        if (isCurrent) return
        e.preventDefault()
        dragCounter++
        if (dragCounter === 1) {
          clearAllHighlights()
          el.style.transform = 'scale(1.2)'
          el.style.boxShadow = '0 0 0 3px #84cc16, 0 0 15px #84cc16'
        }
      }

      const leaveHandler = (e) => {
        if (isCurrent) return
        dragCounter--
        if (dragCounter === 0) {
          el.style.transform = ''
          el.style.boxShadow = ''
        }
      }

      const overHandler = (e) => {
        if (!this.draggedTaskId) return
        if (isCurrent) return
        e.preventDefault()
      }

      el.addEventListener('dragenter', enterHandler)
      el.addEventListener('dragleave', leaveHandler)
      el.addEventListener('dragover', overHandler)

      this.sidebarProjectHandlers.push({ el, enterHandler, leaveHandler, overHandler })
    })

    // Setup inbox drop target (only if not currently on inbox)
    if (inbox && !this.inboxValue) {
      inbox.classList.add('drop-target')
      let inboxDragCounter = 0

      const enterHandler = (e) => {
        if (!this.draggedTaskId) return
        e.preventDefault()
        inboxDragCounter++
        if (inboxDragCounter === 1) {
          clearAllHighlights()
          inbox.style.transform = 'scale(1.2)'
          inbox.style.boxShadow = '0 0 0 3px #84cc16, 0 0 15px #84cc16'
        }
      }

      const leaveHandler = (e) => {
        inboxDragCounter--
        if (inboxDragCounter === 0) {
          inbox.style.transform = ''
          inbox.style.boxShadow = ''
        }
      }

      const overHandler = (e) => {
        if (!this.draggedTaskId) return
        e.preventDefault()
      }

      inbox.addEventListener('dragenter', enterHandler)
      inbox.addEventListener('dragleave', leaveHandler)
      inbox.addEventListener('dragover', overHandler)

      this.sidebarProjectHandlers.push({ el: inbox, enterHandler, leaveHandler, overHandler })
    } else if (inbox && this.inboxValue) {
      inbox.classList.add('drop-target', 'current-project')
    }

    // Setup Today drop target (only if not currently on Today)
    if (today && !this.todayValue) {
      today.classList.add('drop-target')
      let todayDragCounter = 0

      const enterHandler = (e) => {
        if (!this.draggedTaskId) return
        e.preventDefault()
        todayDragCounter++
        if (todayDragCounter === 1) {
          clearAllHighlights()
          today.style.transform = 'scale(1.2)'
          today.style.boxShadow = '0 0 0 3px #84cc16, 0 0 15px #84cc16'
        }
      }

      const leaveHandler = (e) => {
        todayDragCounter--
        if (todayDragCounter === 0) {
          today.style.transform = ''
          today.style.boxShadow = ''
        }
      }

      const overHandler = (e) => {
        if (!this.draggedTaskId) return
        e.preventDefault()
      }

      today.addEventListener('dragenter', enterHandler)
      today.addEventListener('dragleave', leaveHandler)
      today.addEventListener('dragover', overHandler)

      this.sidebarProjectHandlers.push({ el: today, enterHandler, leaveHandler, overHandler })
    } else if (today && this.todayValue) {
      today.classList.add('drop-target', 'current-project')
    }
  }

  cleanupSidebarDropTargets() {
    // Remove event listeners from sidebar projects and inbox
    if (this.sidebarProjectHandlers) {
      this.sidebarProjectHandlers.forEach(({ el, enterHandler, leaveHandler, overHandler }) => {
        el.removeEventListener('dragenter', enterHandler)
        el.removeEventListener('dragleave', leaveHandler)
        el.removeEventListener('dragover', overHandler)
      })
      this.sidebarProjectHandlers = []
    }

    // Clean up classes and inline styles for projects
    document.querySelectorAll('.sidebar-project[data-project-id]').forEach(el => {
      el.classList.remove('drop-target', 'current-project', 'drag-over')
      el.style.transform = ''
      el.style.boxShadow = ''
    })

    // Clean up inbox
    const inbox = document.querySelector('.sidebar-inbox')
    if (inbox) {
      inbox.classList.remove('drop-target', 'current-project')
      inbox.style.transform = ''
      inbox.style.boxShadow = ''
    }

    // Clean up today
    const today = document.querySelector('.sidebar-today')
    if (today) {
      today.classList.remove('drop-target', 'current-project')
      today.style.transform = ''
      today.style.boxShadow = ''
    }
  }

  move(event) {
    // Prevent moving after the plus/trash box
    const plusTrashElement = event.related?.closest('[data-sortable-target="plusTrashBox"]')

    if (plusTrashElement || event.related?.matches('[data-sortable-target="plusTrashBox"]')) {
      return false
    }

    // Don't allow moving hidden (filtered) items
    if (event.related?.style?.display === 'none') {
      return false
    }

    return true
  }

  handleTrashEnter(event) {
    if (this.draggedTaskId) {
      this.isOverTrash = true
      this.trashBoxTarget.classList.add("hover")
    }
  }

  handleTrashLeave(event) {
    this.isOverTrash = false
    this.trashBoxTarget.classList.remove("hover")
  }

  end(event) {
    // Get drop coordinates for element detection
    const touch = event.originalEvent?.touches?.[0] ||
                 event.originalEvent?.changedTouches?.[0] ||
                 event.originalEvent
    const dropX = touch?.clientX
    const dropY = touch?.clientY

    // Check if dropped on sidebar inbox, today, or project
    if (dropX && dropY && this.draggedTaskId) {
      const elementAtPoint = document.elementFromPoint(dropX, dropY)

      // Check for inbox drop first
      const sidebarInbox = elementAtPoint?.closest('.sidebar-inbox')
      if (sidebarInbox && !this.inboxValue) {
        // Valid drop on inbox (and we're not already on inbox)
        this.sendToProject(this.draggedTaskId, 'inbox', event.item)
        this.cleanupSidebarDropTargets()
        this.draggedTaskId = null
        return
      }

      // Check for Today drop
      const sidebarToday = elementAtPoint?.closest('.sidebar-today')
      if (sidebarToday && !this.todayValue) {
        // Valid drop on Today (and we're not already on Today)
        this.sendToToday(this.draggedTaskId, event.item)
        this.cleanupSidebarDropTargets()
        this.draggedTaskId = null
        return
      }

      // Check for project drop
      const sidebarProject = elementAtPoint?.closest('.sidebar-project[data-project-id]')
      if (sidebarProject) {
        const targetProjectId = parseInt(sidebarProject.dataset.projectId, 10)
        if (targetProjectId !== this.projectIdValue) {
          // Valid drop on different project
          this.sendToProject(this.draggedTaskId, targetProjectId, event.item)
          this.cleanupSidebarDropTargets()
          this.draggedTaskId = null
          return
        }
      }
    }

    // Check if dropped on trash
    const droppedOnTrash = this.isOverTrash ||
                          (this.hasTrashBoxTarget && this.trashBoxTarget.contains(event.item))

    // Mobile detection: check if drop position is over trash box
    let isOverTrashOnMobile = false
    if (dropX && dropY && this.hasTrashBoxTarget) {
      const elementAtPoint = document.elementFromPoint(dropX, dropY)
      isOverTrashOnMobile = this.trashBoxTarget.contains(elementAtPoint)
    }

    this.isOverTrash = false

    if ((droppedOnTrash || isOverTrashOnMobile) && this.draggedTaskId) {
      this.deleteTask(this.draggedTaskId, event.item)
    } else {
      this.restorePlusButton()

      // Get all visible task IDs in their new order (excluding filtered/hidden tasks)
      const taskIds = Array.from(this.listTarget.querySelectorAll("[data-task-id]"))
        .filter(el => el.style.display !== 'none')
        .map(element => element.dataset.taskId)

      this.updatePositions(taskIds)
    }

    this.cleanupSidebarDropTargets()
    this.draggedTaskId = null
  }

  async sendToProject(taskId, targetProjectId, taskElement) {
    // Get project name from sidebar element for flash message
    let projectName
    if (targetProjectId === 'inbox') {
      projectName = 'Inbox'
    } else {
      const targetProjectEl = document.querySelector(`.sidebar-project[data-project-id="${targetProjectId}"]`)
      projectName = targetProjectEl?.getAttribute('title') || 'project'
    }

    // Animate and remove task from DOM
    taskElement.classList.add("task-deleting")
    await new Promise(resolve => setTimeout(resolve, 200))
    taskElement.remove()

    this.updateProgressBar()
    this.restorePlusButton()
    this.showFlashMessage(`Moved to ${projectName}`)

    const startEvent = new CustomEvent("turbo:submit-start")
    document.dispatchEvent(startEvent)

    try {
      const response = await fetch(`${this.baseUrl}/tasks/${taskId}/send_to?target_project_id=${targetProjectId}&position=top`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        // Clear Turbo cache so target project shows the new task
        Turbo.cache.clear()
      } else {
        console.error("Failed to send task to project")
        window.location.reload()
      }
    } catch (error) {
      console.error("Error sending task to project:", error)
      window.location.reload()
    } finally {
      const endEvent = new CustomEvent("turbo:submit-end")
      document.dispatchEvent(endEvent)
    }
  }

  async sendToToday(taskId, taskElement) {
    // Task stays in current project, just sets due_date to today
    this.restorePlusButton()
    this.showFlashMessage("Added to today")

    const startEvent = new CustomEvent("turbo:submit-start")
    document.dispatchEvent(startEvent)

    try {
      const response = await fetch(`${this.baseUrl}/tasks/${taskId}/send_to?target_project_id=today`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        // Clear Turbo cache so Today view will show the updated task
        Turbo.cache.clear()
      } else {
        console.error("Failed to add task to today")
        window.location.reload()
      }
    } catch (error) {
      console.error("Error adding task to today:", error)
      window.location.reload()
    } finally {
      const endEvent = new CustomEvent("turbo:submit-end")
      document.dispatchEvent(endEvent)
    }
  }

  restorePlusButton() {
    if (this.hasTrashBoxTarget && this.hasPlusTrashBoxTarget) {
      this.trashBoxTarget.classList.add("hidden")
      this.trashBoxTarget.classList.remove("flex", "hover")
      this.plusTrashBoxTarget.classList.add("hidden")
      this.plusTrashBoxTarget.classList.remove("h-24")
      if (this.hasPlusButtonTarget) {
        this.plusButtonTarget.classList.remove("hidden")
        this.plusTrashBoxTarget.classList.add("h-12")
      }
    }
  }

  async updatePositions(taskIds) {
    const startEvent = new CustomEvent("turbo:submit-start")
    document.dispatchEvent(startEvent)

    try {
      const response = await fetch(`${this.baseUrl}/tasks/reorder`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ task_ids: taskIds })
      })

      if (!response.ok) {
        console.error("Failed to update task positions")
      }
    } catch (error) {
      console.error("Error updating task positions:", error)
    } finally {
      const endEvent = new CustomEvent("turbo:submit-end")
      document.dispatchEvent(endEvent)
    }
  }

  async deleteTask(taskId, taskElement) {
    taskElement.classList.add("task-deleting")
    await new Promise(resolve => setTimeout(resolve, 200))
    taskElement.remove()

    this.updateProgressBar()
    this.restorePlusButton()
    this.showFlashMessage("Task deleted")

    const startEvent = new CustomEvent("turbo:submit-start")
    document.dispatchEvent(startEvent)

    try {
      const response = await fetch(`${this.baseUrl}/tasks/${taskId}`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (!response.ok) {
        console.error("Failed to delete task")
        window.location.reload()
      }
    } catch (error) {
      console.error("Error deleting task:", error)
      window.location.reload()
    } finally {
      const endEvent = new CustomEvent("turbo:submit-end")
      document.dispatchEvent(endEvent)
    }
  }

  updateProgressBar() {
    // Find task list ID from completed tasks list
    const completedList = this.element.querySelector('[id^="completed-tasks-"]')
    const taskListId = completedList?.id.match(/completed-tasks-(\d+)/)?.[1]

    if (!taskListId) return

    const tasksList = document.getElementById('tasks-list')
    const incompleteCount = tasksList ? tasksList.querySelectorAll('[data-task-id]').length : 0
    const completedCount = completedList ? completedList.querySelectorAll('[data-task-id]').length : 0

    // Update completed count display
    const countTarget = this.element.querySelector('[data-completed-tasks-target="count"]')
    if (countTarget) {
      countTarget.textContent = completedCount
    }

    // Update navbar task count
    const navbarCount = document.getElementById('navbar-task-count')
    if (navbarCount) {
      navbarCount.textContent = `${incompleteCount} ${incompleteCount === 1 ? 'task' : 'tasks'}`
    }

    // Update navbar progress bar
    const totalCount = incompleteCount + completedCount
    const progressPercent = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0
    const progressBar = document.getElementById('navbar-progress-bar')
    if (progressBar) {
      progressBar.style.width = `${progressPercent}%`
    }

    // Show/hide completed section
    const completedSection = document.getElementById(`completed-section-${taskListId}`)
    if (completedSection) {
      if (completedCount > 0) {
        completedSection.classList.remove('hidden')
      } else {
        completedSection.classList.add('hidden')
      }
    }
  }

  showFlashMessage(message) {
    const flashContainer = document.getElementById('tasks')
    if (!flashContainer) return

    const flashDiv = document.createElement('div')
    flashDiv.className = 'fixed top-4 left-1/2 -translate-x-1/2 z-[100] pointer-events-none'
    flashDiv.innerHTML = `
      <div data-controller="flash" class="py-1.5 px-3 bg-lime-50 dark:bg-lime-900/30 text-lime-600 dark:text-lime-400 text-xs font-medium rounded-md transition-opacity duration-500 shadow-sm whitespace-nowrap" role="alert">
        ${message}
      </div>
    `

    flashContainer.appendChild(flashDiv)
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }

  get baseUrl() {
    return this.inboxValue ? "/inbox" : `/projects/${this.projectIdValue}`
  }
}
