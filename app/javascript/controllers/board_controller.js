import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="board"
export default class extends Controller {
  connect() {
    // Animate cards on page load with staggered delays
    this.animateCardsEntrance()
  }

  openNewTaskModal(event) {
    event.preventDefault()
    // Get the current board path from the URL
    const path = window.location.pathname
    const newTaskPath = `${path}/tasks/new`
    Turbo.visit(newTaskPath, { frame: "new_task_modal" })
  }

  animateCardsEntrance() {
    const cards = this.element.querySelectorAll('[data-task-id]')
    cards.forEach((card, i) => {
      // Set initial state
      card.style.opacity = '0'
      card.style.transform = 'translateY(10px)'

      // Stagger the entrance animation
      setTimeout(() => {
        card.style.transition = 'opacity 300ms ease-out, transform 300ms ease-out'
        card.style.opacity = '1'
        card.style.transform = 'translateY(0)'

        // Clean up inline styles after animation completes
        setTimeout(() => {
          card.style.transition = ''
          card.style.opacity = ''
          card.style.transform = ''
        }, 300)
      }, i * 40) // 40ms stagger between each card
    })
  }
}
