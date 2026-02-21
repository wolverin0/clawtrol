# frozen_string_literal: true

# Minimal broadcaster for Codemap MVP events.
# Use from Rails console to emit demo events quickly.
class CodemapBroadcaster
  EVENTS = %w[state_sync tile_patch sprite_patch camera selection debug_overlay].freeze

  attr_reader :task_id, :map_id

  def initialize(task_id:, map_id:)
    @task_id = task_id
    @map_id = map_id
    @seq = 0
  end

  def emit(event, data = {}, seq: nil)
    raise ArgumentError, "unsupported event: #{event}" unless EVENTS.include?(event.to_s)

    current_seq = seq || next_seq

    AgentActivityChannel.broadcast_codemap(
      task_id: task_id,
      map_id: map_id,
      event: event.to_s,
      seq: current_seq,
      data: data
    )

    current_seq
  end

  private

  def next_seq
    @seq += 1
  end
end
