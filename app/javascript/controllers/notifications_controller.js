import { Controller } from "@hotwired/stimulus"

// Notifications bell with dropdown panel
// Fetches notifications from API, shows unread count badge, and handles read/navigation
export default class extends Controller {
  static targets = ["badge", "panel", "list", "empty", "count"]
  static values = {
    url: { type: String, default: "/api/v1/notifications" },
    interval: { type: Number, default: 30000 },
    browserNotifications: { type: Boolean, default: true }
  }

  connect() {
    this.isOpen = false
    this.notifications = []
    this.unreadCount = 0
    this.lastNotificationId = null

    // Request browser notification permission on first interaction
    this.permissionRequested = false

    // Initial fetch
    this.fetchNotifications()

    // Start polling
    this.startPolling()

    // Close panel when clicking outside
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener('click', this.boundCloseOnOutsideClick)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener('click', this.boundCloseOnOutsideClick)
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.fetchNotifications(), this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
    }
  }

  async fetchNotifications() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        const previousUnreadCount = this.unreadCount
        
        this.notifications = data.notifications
        this.unreadCount = data.unread_count

        this.updateBadge()
        if (this.isOpen) {
          this.renderNotifications()
        }

        // Show browser notification for new notifications
        if (this.browserNotificationsValue && 
            previousUnreadCount > 0 && 
            this.unreadCount > previousUnreadCount &&
            this.notifications.length > 0) {
          this.showBrowserNotification(this.notifications[0])
        }
      }
    } catch (error) {
      console.error('Error fetching notifications:', error)
    }
  }

  updateBadge() {
    if (this.hasBadgeTarget) {
      if (this.unreadCount > 0) {
        this.badgeTarget.textContent = this.unreadCount > 99 ? '99+' : this.unreadCount
        this.badgeTarget.classList.remove('hidden')
      } else {
        this.badgeTarget.classList.add('hidden')
      }
    }
  }

  toggle(event) {
    event.stopPropagation()
    
    // Request browser notification permission on first toggle
    if (!this.permissionRequested && this.browserNotificationsValue) {
      this.requestNotificationPermission()
    }

    this.isOpen = !this.isOpen
    if (this.isOpen) {
      this.renderNotifications()
      this.panelTarget.classList.remove('hidden')
    } else {
      this.panelTarget.classList.add('hidden')
    }
  }

  closeOnOutsideClick(event) {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.isOpen = false
      this.panelTarget.classList.add('hidden')
    }
  }

  renderNotifications() {
    if (!this.hasListTarget) return

    if (this.notifications.length === 0) {
      this.listTarget.innerHTML = `
        <div class="px-4 py-8 text-center text-content-muted text-sm">
          <span class="text-2xl block mb-2">🔔</span>
          No notifications yet
        </div>
      `
      return
    }

    this.listTarget.innerHTML = this.notifications.map(n => this.renderNotificationItem(n)).join('')
  }

  renderNotificationItem(notification) {
    const unreadClass = notification.read ? 'opacity-60' : ''
    const unreadDot = notification.read ? '' : '<span class="w-2 h-2 bg-accent rounded-full flex-shrink-0"></span>'
    
    return `
      <div class="notification-item flex items-start gap-3 px-4 py-3 hover:bg-bg-elevated cursor-pointer transition-colors border-b border-border/50 last:border-b-0 ${unreadClass}"
           data-action="click->notifications#clickNotification"
           data-notification-id="${notification.id}"
           data-task-id="${notification.task_id || ''}"
           data-board-id="${notification.board_id || ''}">
        <span class="text-lg flex-shrink-0">${notification.icon}</span>
        <div class="flex-1 min-w-0">
          <p class="text-sm text-content line-clamp-2">${this.escapeHtml(notification.message)}</p>
          <p class="text-xs text-content-muted mt-1">${notification.time_ago}</p>
        </div>
        ${unreadDot}
      </div>
    `
  }

  async clickNotification(event) {
    const item = event.currentTarget
    const notificationId = item.dataset.notificationId
    const taskId = item.dataset.taskId
    const boardId = item.dataset.boardId

    // Mark as read
    if (notificationId) {
      await this.markAsRead(notificationId)
    }

    // Navigate to task if available
    if (taskId && boardId) {
      window.location.href = `/boards/${boardId}/tasks/${taskId}`
    }
  }

  async markAsRead(notificationId) {
    try {
      const response = await fetch(`${this.urlValue}/${notificationId}/mark_read`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        this.unreadCount = data.unread_count
        this.updateBadge()

        // Update the notification in our local array
        const notification = this.notifications.find(n => n.id == notificationId)
        if (notification) {
          notification.read = true
        }
      }
    } catch (error) {
      console.error('Error marking notification as read:', error)
    }
  }

  async markAllRead(event) {
    event.stopPropagation()
    
    try {
      const response = await fetch(`${this.urlValue}/mark_all_read`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        this.unreadCount = 0
        this.notifications.forEach(n => n.read = true)
        this.updateBadge()
        this.renderNotifications()
      }
    } catch (error) {
      console.error('Error marking all notifications as read:', error)
    }
  }

  // Browser Notifications API
  async requestNotificationPermission() {
    this.permissionRequested = true
    
    if (!('Notification' in window)) {
      console.log('Browser does not support notifications')
      return
    }

    if (Notification.permission === 'default') {
      await Notification.requestPermission()
    }
  }

  showBrowserNotification(notification) {
    if (!('Notification' in window) || Notification.permission !== 'granted') {
      return
    }

    const browserNotification = new Notification('ClawDeck', {
      body: notification.message,
      icon: '/favicon.ico',
      tag: `notification-${notification.id}`,
      requireInteraction: false
    })

    browserNotification.onclick = () => {
      window.focus()
      if (notification.task_id && notification.board_id) {
        window.location.href = `/boards/${notification.board_id}/tasks/${notification.task_id}`
      }
      browserNotification.close()
    }

    // Auto-close after 5 seconds
    setTimeout(() => browserNotification.close(), 5000)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
