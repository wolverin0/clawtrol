import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "dropdown", "display", "input", "monthYear", "grid"]
  static values = { date: String }

  connect() {
    this.selectedDate = this.dateValue ? new Date(this.dateValue + 'T00:00:00') : null
    this.viewDate = this.selectedDate ? new Date(this.selectedDate) : new Date()
    this.isOpen = false

    // Close on outside click
    this.boundCloseOnOutside = this.closeOnOutside.bind(this)
    document.addEventListener('click', this.boundCloseOnOutside)
  }

  disconnect() {
    document.removeEventListener('click', this.boundCloseOnOutside)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    this.dropdownTarget.classList.remove('hidden')
    this.renderCalendar()
  }

  close() {
    this.isOpen = false
    this.dropdownTarget.classList.add('hidden')
  }

  closeOnOutside(event) {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.close()
    }
  }

  prevMonth(event) {
    event.stopPropagation()
    this.viewDate.setMonth(this.viewDate.getMonth() - 1)
    this.renderCalendar()
  }

  nextMonth(event) {
    event.stopPropagation()
    this.viewDate.setMonth(this.viewDate.getMonth() + 1)
    this.renderCalendar()
  }

  selectToday(event) {
    event.stopPropagation()
    const today = new Date()
    this.viewDate = new Date(today)
    this.renderCalendar()
  }

  selectDate(event) {
    event.stopPropagation()
    const day = parseInt(event.currentTarget.dataset.day)
    const month = parseInt(event.currentTarget.dataset.month)
    const year = parseInt(event.currentTarget.dataset.year)

    this.selectedDate = new Date(year, month, day)
    this.renderCalendar()
  }

  apply(event) {
    event.stopPropagation()
    if (this.selectedDate) {
      const formatted = this.formatDateForInput(this.selectedDate)
      this.inputTarget.value = formatted
      this.updateDisplay()

      // Dispatch change event for auto-save
      this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
    }
    this.close()
  }

  cancel(event) {
    event.stopPropagation()
    // Reset to original value
    this.selectedDate = this.inputTarget.value ? new Date(this.inputTarget.value + 'T00:00:00') : null
    this.viewDate = this.selectedDate ? new Date(this.selectedDate) : new Date()
    this.close()
  }

  clear(event) {
    event.stopPropagation()
    this.selectedDate = null
    this.inputTarget.value = ''
    this.updateDisplay()
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
    this.close()
  }

  updateDisplay() {
    if (this.hasDisplayTarget) {
      if (this.selectedDate) {
        this.displayTarget.textContent = this.formatDateForDisplay(this.selectedDate)
      } else {
        this.displayTarget.textContent = 'None'
      }
    }
  }

  formatDateForInput(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  formatDateForDisplay(date) {
    const day = date.getDate()
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    const month = months[date.getMonth()]
    const year = date.getFullYear()
    return `${month} ${day}, ${year}`
  }

  renderCalendar() {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

    // Update month/year header
    this.monthYearTarget.textContent = `${months[this.viewDate.getMonth()]} ${this.viewDate.getFullYear()}`

    // Build calendar grid
    const year = this.viewDate.getFullYear()
    const month = this.viewDate.getMonth()

    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)
    const daysInMonth = lastDay.getDate()

    // Get day of week (0 = Sunday, adjust to Monday = 0)
    let startDay = firstDay.getDay() - 1
    if (startDay < 0) startDay = 6

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    let html = ''

    // Previous month days
    const prevMonth = new Date(year, month, 0)
    const prevMonthDays = prevMonth.getDate()
    for (let i = startDay - 1; i >= 0; i--) {
      const day = prevMonthDays - i
      html += `<button type="button" data-action="click->datepicker#selectDate" data-day="${day}" data-month="${month - 1}" data-year="${year}" class="h-8 w-8 rounded-md text-neutral-600 hover:bg-neutral-800 transition-colors text-xs">${day}</button>`
    }

    // Current month days
    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(year, month, day)
      const isToday = date.getTime() === today.getTime()
      const isSelected = this.selectedDate &&
        date.getDate() === this.selectedDate.getDate() &&
        date.getMonth() === this.selectedDate.getMonth() &&
        date.getFullYear() === this.selectedDate.getFullYear()

      let classes = 'h-8 w-8 rounded-md text-xs transition-colors cursor-pointer '
      if (isSelected) {
        classes += 'bg-orange-500 text-white hover:bg-orange-600'
      } else if (isToday) {
        classes += 'text-orange-500 font-semibold hover:bg-neutral-800'
      } else {
        classes += 'text-neutral-300 hover:bg-neutral-800'
      }

      html += `<button type="button" data-action="click->datepicker#selectDate" data-day="${day}" data-month="${month}" data-year="${year}" class="${classes}">${day}</button>`
    }

    // Next month days
    const totalCells = Math.ceil((startDay + daysInMonth) / 7) * 7
    const nextMonthDays = totalCells - startDay - daysInMonth
    for (let day = 1; day <= nextMonthDays; day++) {
      html += `<button type="button" data-action="click->datepicker#selectDate" data-day="${day}" data-month="${month + 1}" data-year="${year}" class="h-8 w-8 rounded-md text-neutral-600 hover:bg-neutral-800 transition-colors text-xs">${day}</button>`
    }

    this.gridTarget.innerHTML = html
  }
}
