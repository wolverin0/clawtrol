# OpenClaw Runtime Fix Report (2026-02-21)

## Context
The bot stopped replying consistently in PM/topic and produced repeated errors:
- `session file locked (timeout 10000ms)`
- slow/no replies after message intake
- intermittent Telegram API network failures in logs

## Root Cause Confirmed
A long-running AutoPull execution held the main session lock:
- service: `openclaw-clawtrol-autopull.service`
- child process: `openclaw-agent` (PID holding lock)
- lock file: `~/.openclaw/agents/main/sessions/9df64ff3-84aa-4c10-aa07-47cd968af4ea.jsonl.lock`

Because that lock belonged to a live process, all providers failed on the same lock timeout.

## Actions Performed
1. Identified the stuck process tree from AutoPull service into `openclaw-agent`.
2. Stopped the stuck AutoPull execution.
3. Removed the stale lock file for the main session.
4. Restarted `openclaw-gateway.service` and `openclaw-node.service`.
5. Verified Telegram channel probe was healthy.
6. Left `openclaw-clawtrol-autopull.timer` paused to avoid re-lock until script hardening is applied.

## Validation Snapshot
- timestamp: 2026-02-21T09:39:07-03:00
- gateway: `active`
- node: `active`
- autopull timer: `inactive` (intentionally paused)
- main lock file: not present (`no_main_lock`)

## Upstream Correlation (GitHub)
Recent upstream issues show similar behavior:
- #21783 Session lock never auto-cleans when held by gateway process
- #18140 stale `.jsonl.lock` under cron load
- #22133 heartbeat model override bleeding into main session
- #22181 cron isolated session reuse issue
- #22193 / #22146 / #22204 pairing and spawn instability

Repository: https://github.com/openclaw/openclaw/issues

## Recommended Next Hardening
- Patch `clawtrol_autopull.py` to never run against/lock the main conversational session path.
- Ensure AutoPull runs short-lived and non-blocking (no long embedded runs in oneshot timer units).
- Re-enable `openclaw-clawtrol-autopull.timer` only after the patch.
