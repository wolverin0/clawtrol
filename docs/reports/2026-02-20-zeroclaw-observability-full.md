# ZeroClaw Observability Full Stack — 2026-02-20

## Summary
- /zerobitch fleet cards surface observability settings from agent configs and keep template edits persisted across refreshes.
- Status mapping and logs modal wiring confirmed in controller/view/Stimulus paths.
- /view download UX keeps the download button working even when files exceed inline size limits.

## Files Changed
- /home/ggorbalan/clawdeck/app/controllers/file_viewer_controller.rb

## Validation
- `bin/rails routes | rg "zerobitch_agent_template|zerobitch_agent_logs|view"`
  - `zerobitch_agent_logs` => `GET /zerobitch/agents/:id/logs`
  - `zerobitch_agent_template` => `PATCH /zerobitch/agents/:id/template`
  - `view` => `GET/PUT /view`

## Status Mapping Evidence
- `ZerobitchController#docker_status_for` maps docker states to UI statuses (running/paused/restarting/dead/stopped/unknown) and feeds `status_label` for cards.
- `_agent_card.html.erb` and `zerobitch_fleet_controller.js` use matching badge class mappings for those statuses.

## Logs Modal Evidence
- `/zerobitch` modal (`app/views/zerobitch/index.html.erb`) targets `logsModal/logsOutput/logsTail`.
- `zerobitch_fleet_controller.js#openLogs` fetches `/zerobitch/agents/:id/logs` with tail param and renders output.

## Template Persistence Evidence
- `zerobitch_fleet_controller.js#saveTemplate` PATCHes `/zerobitch/agents/:id/template` with JSON body.
- `ZerobitchController#save_template` accepts root or nested template params and persists to `Zerobitch::AgentRegistry`.
- `build_agent_snapshot` returns `template`, keeping edits visible on the next metrics refresh.

## Notes
- No automated tests run beyond route inspection.
