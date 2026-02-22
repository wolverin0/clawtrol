# Queue Orchestration Simulation (40 Tasks)

Date: 2026-02-21T22:25:10Z
User: queue-sim-6b94f34a@example.test

## Setup
- Boards: 4
- Seeded up_next tasks: 40
- Busy boards at start: 1 (18)
- Models mix: codex, sonnet, gemini3, glm
- Time context: 2026-02-08 23:30:00 -0300 (night window)

## Pass 1 (selector.plan limit=40)
- max_concurrent: 8
- available_slots: 7
- tasks selected: 3
- selected task ids: 383, 393, 403
- selected board ids: 19, 20, 21
- skip reasons: {"board_busy"=>37}

## Pass 2 (after simulating claims)
- max_concurrent: 8
- available_slots: 4
- tasks selected: 0
- selected board ids: 
- skip reasons: {"board_busy"=>37}

## Verdict
- One-per-board selection: PASS
- Busy-board suppression: PASS
- FIFO inside board: PASS
