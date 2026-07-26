You are Claude Code working inside the ClawDeck Rails repo for Gonzalo/Snake.

Implement the dual OpenClaw + Hermes ClawTrol plan incrementally, preserving OpenClaw behavior.

Read this plan first:
/home/ggorbalan/clawdeck/.hermes/plans/2026-05-21_121210-dual-openclaw-hermes-clawtrol.md

Hard constraints:
- Do NOT remove OpenClaw support.
- OpenClaw must remain default/backward compatible.
- Prefer small, tested changes.
- Do not commit or push.
- Do not expose secrets.
- Avoid changing unrelated UI unless needed.

Target MVP for this run:
1. Restore Docker build if Dockerfile is missing libyaml-dev for psych.
2. Add platform configuration fields and model validation:
   - user orchestration modes: openclaw_only, hermes_only, dual
   - preferred_agent_platform default openclaw
   - hermes_home default ~/.hermes
   - hermes_profile nullable
   - hermes_gateway_url/token/hooks_token nullable, encrypted if consistent with existing token fields
3. Add AgentPlatform registry/base/result structure.
4. Add OpenClaw adapter that wraps/delegates existing OpenClaw behavior without deleting old classes.
5. Add Hermes CLI runner + Hermes adapter with safe offline behavior.
   - health/status/config/model basic support
   - cron/session read-only if straightforward
   - missing CLI/unsupported actions must return structured offline/unsupported results, not crash
6. Make FileViewerController support explicit logical roots for both OpenClaw and Hermes artifacts:
   - openclaw/<path>
   - hermes/<path>
   - reports/<path>
   - clawdeck/<path>
   - preserve bare path backward compatibility to OpenClaw workspace
   - preserve traversal/dotfile/symlink protections
7. Add/adjust focused tests for model validation, adapter registry/offline behavior, Hermes runner, and viewer roots.
8. Run targeted tests if possible. If tests fail due to existing unrelated environment issues, document exactly.

Use Rails conventions already in this repo. Before editing, inspect relevant files. After editing, provide a concise summary of changed files and test results.