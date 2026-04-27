---
name: audit-blind-spots
description: Walk the B1-B15 AI-to-AI blind-spot catalog systematically. Use during the audit pipeline AFTER hard-stops and Tambon hunt and BEFORE the 13 domain audits. Output: PRESENT / NOT PRESENT for each B-class with evidence. Findings flow into the appropriate domains.
---

# Skill: Audit Blind Spots Walk

This skill walks the 15 AI-to-AI blind spots from
`@.claude/context/audit-blind-spots.md` and produces a structured
report. The findings are then routed by the orchestrator into the
appropriate domain sections.

## Why this is a separate skill (not folded into domains)

Blind spots cross domain boundaries. B1 (auth not wired) is a security
finding AND a code-quality finding AND a reliability finding. Running
the blind-spot walk once and routing findings into domains is more
efficient than asking each domain to re-discover its share.

## Process

### Pre-flight

```
view @.claude/context/audit-rules.md
view @.claude/context/audit-blind-spots.md
```

### Walk B1-B15 in order

For each B-class, follow the detection commands from
audit-blind-spots.md. The walk is mostly grep + read, but B1, B7, B8
require substantial code-tracing.

### Per-blind-spot template

```
═══════════════════════════════════════════════════════════════════════
  B<N> — <n>
═══════════════════════════════════════════════════════════════════════

Detection commands run:
  <list>

If output is clean:
  Status:   NOT PRESENT
  Notes:    <e.g., "no auth middleware found, but app uses Supabase Auth
                    integrated into FastAPI dependencies — different
                    pattern, B1 doesn't apply">

If output has matches:
  Status:   PRESENT (<N> instances)

  Findings:
    F-B<N>.1
      Evidence:        <path:line>
      Pattern:         <which sub-pattern>
      Severity:        Critical | High | Medium | Low
      Routing:         Domain <N>  (which domain this finding belongs to)
      What's wrong:    <one paragraph>
      Why it matters:  <one sentence>

    [F-B<N>.2 etc. if more]
```

## Routing table — where each B finding goes

The orchestrator uses this to put findings in the right domain section:

| Blind spot | Primary domain | Secondary domain |
|---|---|---|
| B1 (Auth not wired) | Domain 1 (Security) | — |
| B2 (Error returns success) | Domain 7 (Reliability) | Domain 1 |
| B3 (FE-only pagination) | Domain 5 (Performance) | Domain 3 |
| B4 (Soft-delete unfiltered) | Domain 3 (Database) | Domain 1 |
| B5 (Env var existence-only) | Domain 4 (DevOps) | Domain 7 |
| B6 (Single-user assumptions) | Domain 5 (Performance) | Domain 7 |
| B7 (Validation asymmetry) | Domain 1 (Security) | Domain 6 |
| B8 (IDOR) | Domain 1 (Security) | — |
| B9 (Dead utilities) | Domain 13 (Code Integrity) | Domain 9 |
| B10 (Optimistic UI no rollback) | Domain 6 (UX/A11y) | Domain 7 |
| B11 (Webhook idempotency) | Domain 7 (Reliability) | Domain 1 |
| B12 (Stack mixing) | Domain 13 (Code Integrity) | Domain 2 |
| B13 (Test mirrors code) | Domain 13 (Code Integrity) | Domain 9 |
| B14 (Comment-code drift) | Domain 13 (Code Integrity) | Domain 9 |
| B15 (Coverage theater) | Domain 9 (Maintainability) | Domain 13 |

## Output format

```
═══════════════════════════════════════════════════════════════════════
  AI-TO-AI BLIND SPOTS WALK
═══════════════════════════════════════════════════════════════════════

Walked 15 blind-spot classes. Findings routed to domains as follows.

  B1  — Auth present but not wired:           [PRESENT/NOT PRESENT]
  B2  — Error handlers returning success:     [PRESENT/NOT PRESENT]
  B3  — Frontend-only pagination:             [PRESENT/NOT PRESENT]
  B4  — Soft-delete unfiltered:               [PRESENT/NOT PRESENT]
  B5  — Env var existence-only checks:        [PRESENT/NOT PRESENT]
  B6  — Single-user assumptions:              [PRESENT/NOT PRESENT]
  B7  — Validation asymmetry:                 [PRESENT/NOT PRESENT]
  B8  — Authorization gap (IDOR):             [PRESENT/NOT PRESENT]
  B9  — Dead imports / unreachable utils:     [PRESENT/NOT PRESENT]
  B10 — Optimistic UI without rollback:       [PRESENT/NOT PRESENT]
  B11 — Webhook idempotency missing:          [PRESENT/NOT PRESENT]
  B12 — Stack mixing:                         [PRESENT/NOT PRESENT]
  B13 — Test mirrors code:                    [PRESENT/NOT PRESENT]
  B14 — Comment-code drift:                   [PRESENT/NOT PRESENT]
  B15 — Coverage theater:                     [PRESENT/NOT PRESENT]

[Then the detailed findings per PRESENT class, routed to domains]

────────────────────────────────────────────────────────────────────────
SUMMARY
────────────────────────────────────────────────────────────────────────

Present:                      <N> of 15
Most pervasive (highest count): <which blind spot, in how many places>
Critical findings from walk:    <count>
High findings from walk:        <count>

[SECTION COMPLETE: audit-blind-spots]
```

## Failure modes to refuse

- ❌ Skipping a B-class because it "probably doesn't apply" — walk all 15
- ❌ Marking PRESENT without specific evidence (path:line)
- ❌ Routing all findings to the same domain to "consolidate" — use the
  routing table
- ❌ Reading test files for B13 detection but not source files for B14
  detection — they're complementary
