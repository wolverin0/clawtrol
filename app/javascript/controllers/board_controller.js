import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="board"
export default class extends Controller {
  openNewTaskModal(event) {
    event.preventDefault()
    // Get the current board path from the URL
    const path = window.location.pathname
    const newTaskPath = `${path}/tasks/new`
    Turbo.visit(newTaskPath, { frame: "new_task_modal" })
  }
}
