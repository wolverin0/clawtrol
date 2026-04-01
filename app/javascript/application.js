// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// ActionCable channels for WebSocket communication
import "channels"

// Chartkick for analytics charts (dynamic import — CDN failure must not block core JS)
import("chartkick").catch(() => console.warn("chartkick failed to load — charts disabled"))
import("Chart.js").catch(() => console.warn("Chart.js failed to load — charts disabled"))

// Instant modal skeleton — show loading state immediately on task card click
// so the modal appears before Turbo finishes fetching the panel content.
document.addEventListener("click", (e) => {
  const link = e.target.closest('a[data-turbo-frame="task_panel"]')
  if (!link) return
  const frame = document.getElementById("task_panel")
  if (!frame) return
  // Only inject skeleton if frame is currently empty (no modal open)
  if (frame.querySelector('[data-controller~="task-modal"]')) return
  const isDesktop = window.matchMedia("(min-width: 1024px)").matches
  frame.innerHTML = `
    <div data-controller="task-modal" data-task-modal-task-id-value="0">
      <div data-task-modal-target="backdrop" class="hidden opacity-0 fixed inset-0 transition-opacity duration-300 ease-out z-[60] pointer-events-none"></div>
      <div data-task-modal-target="modal" class="hidden fixed z-[70] transition-all duration-300 ease-out
        inset-y-0 right-0 w-full max-w-md md:max-w-lg translate-x-full p-4
        lg:inset-0 lg:translate-x-0 lg:opacity-0 lg:scale-95 lg:p-6 lg:max-w-none lg:flex lg:items-center lg:justify-center">
        <div data-task-modal-target="dragHandle" class="h-full bg-bg-surface border border-border shadow-2xl flex flex-col rounded-xl overflow-hidden
          lg:w-[90vw] lg:max-w-7xl lg:h-[90vh] lg:max-h-[90vh]" style="resize:both; min-width:340px; min-height:300px;">
          <div class="flex-1 flex items-center justify-center">
            <div class="flex flex-col items-center gap-3 text-content-muted">
              <svg class="animate-spin h-8 w-8" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span class="text-sm">Loading task...</span>
            </div>
          </div>
        </div>
      </div>
    </div>`
}, { capture: true })
