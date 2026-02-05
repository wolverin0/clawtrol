// ActionCable channels entry point
import { createConsumer } from "@rails/actioncable"

// Create a single consumer instance for the application
export const consumer = createConsumer()

// Export subscription helpers for Stimulus controllers
export function subscribeToKanban(boardId, callbacks = {}) {
  return consumer.subscriptions.create(
    { channel: "KanbanChannel", board_id: boardId },
    {
      connected() {
        console.log(`[KanbanChannel] Connected to board ${boardId}`)
        callbacks.onConnected?.()
      },
      disconnected() {
        console.log(`[KanbanChannel] Disconnected from board ${boardId}`)
        callbacks.onDisconnected?.()
      },
      received(data) {
        console.log(`[KanbanChannel] Received:`, data)
        callbacks.onReceived?.(data)
      }
    }
  )
}

export function subscribeToAgentActivity(taskId, callbacks = {}) {
  return consumer.subscriptions.create(
    { channel: "AgentActivityChannel", task_id: taskId },
    {
      connected() {
        console.log(`[AgentActivityChannel] Connected to task ${taskId}`)
        callbacks.onConnected?.()
      },
      disconnected() {
        console.log(`[AgentActivityChannel] Disconnected from task ${taskId}`)
        callbacks.onDisconnected?.()
      },
      received(data) {
        console.log(`[AgentActivityChannel] Received:`, data)
        callbacks.onReceived?.(data)
      }
    }
  )
}
