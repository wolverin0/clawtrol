---
description: Run the multi-domain technical due-diligence audit on this codebase. Invokes the audit-orchestrator skill which spawns the audit-runner subagent and produces a single dual-layer report (founder view + technical evidence). Allowed args: --scope=<path>, --priority-domains=<csv>.
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Task, Skill
---

# /audit — Technical Due Diligence Audit

You are about to run the audit-orchestrator skill against this codebase.

## What this command does

1. **Loads the audit-orchestrator skill** from `.claude/skills/audit-orchestrator/SKILL.md`.
2. The skill orchestrates a multi-phase audit pipeline:
   - Phase A — Method (fingerprint stack, inventory, system map)
   - Phase B — Hard Stops (H1-H9 walk)
   - Phase C — Tambon Hunt (LLM-failure-mode signatures)
   - Phase D — Blind Spots (B1-B15 walk)
   - Phase E — 13 domain audits (in parallel subagents)
   - Phase F — Stitch into one report
   - Phase G — Self-check (R1-R7)
3. **Produces a single report** at `audit-report.md` (project root) with:
   - Severity census + one of the five exact verdict strings
   - 13 domain sections with file:line citations for every finding
   - Phased remediation plan with dev-day estimates
4. **Two deterministic hooks fire on Write of `audit-report*.md`**:
   - PreToolUse: `pre-audit-evidence-check.py` — blocks the report if any finding lacks `path:line`, cites a path that doesn't exist, or skips section markers
   - PostToolUse: `post-audit-format-check.py` — warns if the verdict doesn't match the severity census, if domain sections are missing, or if the seven-rules attestation is incomplete

## Arguments

`$ARGUMENTS` is parsed by the orchestrator. Supported:

- `--scope=<relative path>` — audit only this subtree. Default: full repo.
- `--priority-domains=<comma-separated 1-13>` — audit only these domains. Default: all 13.
- `--resume-from=<N>` — resume a previous truncated audit at domain N.

If no arguments, the orchestrator confirms scope with a single short question, then proceeds.

## Time expectation

- Full repo, all 13 domains: 40-70 minutes wall-clock
- Scoped (one subtree, 3-5 domains): 10-20 minutes
- Phase A+B only (kit validation): 5-10 minutes

Tell the user the estimate up front.

## What to do RIGHT NOW

Invoke the audit-orchestrator skill via the `Skill` tool:

```
Skill("audit-orchestrator")
```

Then follow its instructions. Pass the user's `$ARGUMENTS` to the orchestrator's
"Confirm scope" step so it knows whether to ask or proceed.

If the orchestrator skill cannot be loaded (Skill tool returns no match for
"audit-orchestrator"), the kit isn't installed correctly. Tell the user to
verify `.claude/skills/audit-orchestrator/SKILL.md` exists and that
Claude Code was restarted after the kit was copied in.

## Constraints (per the orchestrator's design)

- ❌ Do NOT modify any source code. Read-only audit.
- ❌ Do NOT produce a report without running the domain skills (writing from
  imagination is the v3 prompt's failure mode this kit specifically avoids).
- ❌ Do NOT skip Phase B (hard stops). It MUST run, even if domains are truncated.
- ❌ Do NOT soften the verdict. The triage rubric is deterministic.
- ✅ DO emit `[AUDIT TRUNCATED: <reason>]` honestly if you run out of budget.
- ✅ DO route findings to the correct domain — the orchestrator stitches.

## After the report is written

The user will see the report in their main conversation. The pre-emit hook
will have already validated R1/R2/R4/R6 deterministically. If the hook
blocked the write, fix the violations and re-emit (don't try to bypass it —
there's no override).

For each finding the user wants fixed, they can run `/audit-fix F-X.Y` to
generate a fix prompt for a fresh AI session.
