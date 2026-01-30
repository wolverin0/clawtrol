import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="board"
export default class extends Controller {
  openNewTaskModal(event) {
    event.preventDefault()
    // Use turbo to load the new task form
    Turbo.visit("/board/tasks/new", { frame: "new_task_modal" })
  }
}
