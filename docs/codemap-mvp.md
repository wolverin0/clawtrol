# Codemap MVP (Task #164)

## Added / changed files

- `app/javascript/codemap/renderer.js`
  - Canvas2D tile/sprite renderer using real spritesheets from `public/codemap/raw_assets` via atlas metadata.
  - Keeps fallback placeholders when atlas/images are missing.
  - Supports events: `state_sync`, `tile_patch`, `sprite_patch`, `camera`, `selection`, `debug_overlay`.
  - Ignores out-of-order/duplicate sequence values (`seq <= lastSeq`).
- `app/javascript/codemap/hotel_renderer.js`
  - Hotel-style scene renderer that uses atlas tiles/sprites for rooms and task guests.
- `app/javascript/controllers/codemap_monitor_controller.js`
  - Drives Hotel vs Tech toggle, wires Kanban WebSocket updates, and handles hit-testing for task clicks.
- `app/javascript/controllers/visualizer_controller.js`
  - Initializes renderer, subscribes to ActionCable, handles resize and controls.
- `app/javascript/channels/index.js`
  - Added `subscribeToCodemap(taskId, mapId, callbacks)` helper.
- `app/channels/agent_activity_channel.rb`
  - Extended to stream by `map_id` and broadcast codemap envelope payloads.
- `app/services/codemap_broadcaster.rb`
  - Console-friendly broadcaster for emitting codemap demo events.
- `app/views/boards/tasks/_panel.html.erb`
  - Embedded Codemap panel in transcript/evidence column with controls.
- `app/views/codemap_monitor/index.html.erb`
  - Hotel view canvas plus Tech fallback grid toggle.
- `app/javascript/controllers/index.js`
  - Registered `visualizer` and `codemap-monitor` Stimulus controllers.
- `docs/research/codemap-plan.md`
  - Codemap envelope contract used by channel + frontend.
- `public/codemap/meta/atlas.json`
  - Atlas metadata that maps codemap tiles/sprites to extracted real assets.
- `public/codemap/{tiles,sprites,maps,meta}/.gitkeep`
  - Asset folders expected by renderer.

## How to run

1. Start app normally (Rails + JS watcher as used in this repo).
2. Open any task (Transcript tab includes **Codemap MVP** even before agent activity).
3. Use **Open Monitor** in the widget header to jump to the standalone page.

### Standalone monitor

- URL: `/codemap`
- Default view renders a Hotel scene grouped by status; tasks move rooms on WebSocket status updates.
- Click a hotel guest label to open its task.
- Toggle **Tech** to see the original codemap grid per task.
- Pass `?task_id=123` to highlight/scroll a specific task card.

## Rails console demo sequence

```ruby
# rails c
b = CodemapBroadcaster.new(task_id: 164, map_id: "task_164")

b.emit(:state_sync, {
  map: { width: 24, height: 16, tile_size: 20 },
  tiles: [
    { x: 2, y: 2, atlas_key: "floor" },
    { x: 3, y: 2, atlas_key: "wall" },
    { x: 4, y: 2, tile_id: 12 }
  ],
  sprites: [
    { id: "agent_1", x: 5, y: 6, atlas_key: "snake", label: "Snake" },
    { id: "enemy_1", x: 8, y: 6, atlas_key: "guard", label: "Guard" }
  ],
  camera: { x: 0, y: 0, zoom: 1 }
})

b.emit(:tile_patch, { tiles: [{ x: 6, y: 6, tile_id: 25 }] })
b.emit(:sprite_patch, { sprites: [{ id: "agent_1", x: 7, y: 6, atlas_key: "snake", label: "Snake" }] })
b.emit(:selection, { x: 6, y: 6, w: 2, h: 2 })
b.emit(:camera, { x: 2, y: 1, zoom: 1.15 })
b.emit(:debug_overlay, { enabled: true })
```

## Troubleshooting

- **Waiting for WebSocket**: ActionCable has not connected yet. Check `/cable` access, auth session, and browser console.
- **Access denied**: The subscription was rejected (task not visible to current user or session expired).
- **Missing task**: The widget was initialized without a task ID (unexpected unless the DOM is missing data attributes).
- **Disconnected**: The cable connection dropped; refresh or verify server logs.

## Known limitations

- Placeholder rendering is simple (solid-color tiles/sprites) until art assets are provided.
- No map persistence yet (state is in-memory in browser).
- No interpolation/animation between sprite patches.
