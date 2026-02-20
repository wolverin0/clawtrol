# ZeroClaw Fleet Observability

## Overview
- `/zerobitch` surfaces observability settings from each agent's `config.toml`.
- Source order: `storage/zerobitch/configs/<agent_id>/config.toml`, then `~/zeroclaw-fleet/agents/<name>/config.toml`.
- The UI shows `backend` plus any extra keys in the `[observability]` section.

## Config Example
```toml
[observability]
backend = "log"
```

## Notes
- Use a backend value supported by your ZeroClaw runtime (for example: `log`, `otel`, `prometheus`).
- Any additional keys in `[observability]` are displayed as `key=value` on fleet cards.
- Restart the agent after changing its config to ensure the runtime picks up the new backend.
