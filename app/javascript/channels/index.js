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

export function subscribeToChat(taskId, callbacks = {}) {
  return consumer.subscriptions.create(
    { channel: "ChatChannel", task_id: taskId },
    {
      connected() {
        console.log(`[ChatChannel] Connected to task ${taskId}`)
        callbacks.onConnected?.()
      },
      disconnected() {
        console.log(`[ChatChannel] Disconnected from task ${taskId}`)
        callbacks.onDisconnected?.()
      },
      received(data) {
        console.log(`[ChatChannel] Received:`, data)
        callbacks.onReceived?.(data)
      },
      send(data) {
        this.perform("receive", data)
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
