# Codemap Event Envelope (MVP)

ActionCable payload envelope for Codemap updates:

```json
{
  "type": "codemap_event",
  "task_id": 164,
  "map_id": "task_164",
  "event": "tile_patch",
  "seq": 12,
  "timestamp": 1760000000,
  "data": {}
}
```

## Supported `event` values

- `state_sync` — full/partial state bootstrap
- `tile_patch` — tile upserts
- `sprite_patch` — sprite upserts/deletions
- `camera` — camera position/zoom update
- `selection` — selection rectangle update
- `debug_overlay` — debug HUD toggle

## Notes

- `seq` is monotonic per map stream.
- Clients MUST ignore out-of-order events (`seq <= last_seq`).
- Patch application should be idempotent.
