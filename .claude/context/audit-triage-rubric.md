# Audit Triage Rubric

This file replaces the Vibe Debt Score from v3. The score (0–100 with
bands) was theater — it gave the appearance of objectivity to what is
fundamentally a judgment call, and it nudged auditors toward gaming the
math (one less Critical here, one more Medium there) to land in a
preferred band.

The triage output below is **honest about the judgment** and **specific
about the action**.

---

## What replaces the score

Three artifacts. Together they tell the reader exactly where they stand.

### Artifact 1 — Severity Census

```
SEVERITY CENSUS
─────────────────────────────────────
🛑 Hard Stops:           <count>   (each = launch-blocker)
🔴 Critical findings:    <count>
🟠 High findings:        <count>
🟡 Medium findings:      <count>
🔵 Low findings:         <count>

By exploitability:
  EXPLOITABLE-NOW:        <count>   (script kiddie can abuse today)
  EXPLOITABLE-LOW-EFFORT: <count>
  BAD-PRACTICE:           <count>
  UNKNOWN:                <count>

By domain (most affected first):
  Domain N — <name>:      <count> findings
  Domain M — <name>:      <count> findings
  ...
```

This is purely descriptive. No formula. The reader looks at the numbers
and forms their own judgment.

---

### Artifact 2 — Verdict Statement

ONE of these four exact strings, no fuzzing, no hedging:

| Trigger | Verdict |
|---|---|
| ANY hard stop present | `🛑 DO NOT LAUNCH UNTIL HARD STOPS RESOLVED` |
| ≥1 EXPLOITABLE-NOW finding (no hard stops) | `🔴 BLOCK LAUNCH — fix EXPLOITABLE-NOW findings before any production traffic` |
| ≥3 Critical findings, OR ≥1 Critical in payments/auth/deletes | `🟠 FIX BEFORE LAUNCH — multiple critical issues; estimate days-to-weeks` |
| ≥3 High findings, no Criticals | `🟡 SHIPPABLE WITH PLAN — significant tech debt; schedule remediation sprint` |
| Mostly Medium/Low | `🟢 ACCEPTABLE — routine cleanup; no launch-blockers` |

The verdict is a function of the findings, not the auditor's mood. Two
auditors looking at the same findings should arrive at the same
verdict. That's what the v3 score was *trying* to do; the explicit
triggers do it more cleanly than the formula.

---

### Artifact 3 — Remediation Plan

For each finding bucket, an estimate and a sequence:

```
REMEDIATION PLAN
─────────────────────────────────────

Phase 0 — Hard Stops (do FIRST, before anything else)
  Estimated effort:  <X-Y> developer-days
  Findings included: H1, H3 (above)

  Sequence:
    1. <which hard stop> — <approach in one sentence>
    2. <next hard stop>
    ...

Phase 1 — EXPLOITABLE-NOW findings (do BEFORE first production traffic)
  Estimated effort:  <X-Y> developer-days
  Findings included: F<n>, F<n>, F<n>

  Sequence:
    1. <one sentence>
    2. <one sentence>
    ...

Phase 2 — Critical findings (Phase 1.5 — before scaling user count)
  Estimated effort:  <X-Y> developer-days
  Findings included: F<n>, F<n>, F<n>

Phase 3 — High findings (next sprint)
  Estimated effort:  <X-Y> developer-days

Phase 4 — Medium / Low findings (scheduled cleanup)
  Estimated effort:  <X-Y> developer-days

TOTAL ESTIMATED REMEDIATION: <X-Y> developer-days
```

This is the artifact the founder/PM actually uses. They can plan
sprints around it. They can estimate runway impact. They can negotiate
with stakeholders.

The Vibe Debt Score number was useless for this. "73/100, FIX BEFORE
LAUNCH" doesn't tell anyone how long it takes or what to do first.

---

## How estimates are produced

Estimates are coarse but honest. Use these multipliers per finding:

| Severity / class | Estimate per finding |
|---|---|
| 🛑 Hard Stop (H1, H4 — secrets/keys exposed) | 0.5–2 days (rotation + scrubbing) |
| 🛑 Hard Stop (H2, H3, H5 — wiring issues) | 0.5–1 day |
| 🛑 Hard Stop (H6, H7, H8 — code patterns) | 0.5 day per occurrence |
| 🛑 Hard Stop (H9 — test rewrites) | 1–3 days per critical flow |
| 🔴 Critical | 0.5–1 day |
| 🟠 High | 0.25–0.5 day |
| 🟡 Medium | 0.1–0.25 day |
| 🔵 Low | 0.05 day (5–10 in a batch) |

Add a "duplication tax" if Domain 13 (Code Integrity) found significant
duplication — every fix has to be applied to N copies. Multiply Phase 2-3
by 1.5x if Domain 13 rated 1 or 2.

Add a "test-rewrite tax" if H9 was triggered or if Domain 13 noted
test-mirrors-code patterns. Add 20–30% to Phase 2 effort because every
fix needs a real test added.

State the multipliers used in the report. The reader should be able to
challenge the estimate and recompute it.

---

## What the rubric explicitly does NOT do

- **Does not produce a single number.** No "73/100." A number invites
  comparison and gaming; the verdict + plan invites action.
- **Does not give a verdict band based on math.** The verdict is
  triggered by specific conditions (hard stop, EXPLOITABLE-NOW), not by
  a sum.
- **Does not soften based on aggregate.** Ten Mediums do NOT make a
  "FIX BEFORE LAUNCH" verdict. The conditions are explicit, exhaustive,
  and asymmetric (one Critical can flip the verdict; many Mediums
  cannot).
- **Does not prescribe how the team prioritizes.** It surfaces phases.
  The team decides scope.

---

## How the rubric integrates into the report

The triage block goes near the TOP of the report, immediately after the
hard-stops block (if any). Structure:

```
═══════════════════════════════════════════════════════════════════════
  AUDIT VERDICT
═══════════════════════════════════════════════════════════════════════

[🛑 / 🔴 / 🟠 / 🟡 / 🟢] <VERDICT STATEMENT — exact string from table>

  Severity census: <one-line summary>
  Estimated remediation: <X-Y developer-days> across <N> phases
  See REMEDIATION PLAN below for sequencing.

═══════════════════════════════════════════════════════════════════════
```

Then the Severity Census artifact. Then the Remediation Plan. Then
domain-by-domain findings.

---

## Why this is better than the score

The score in v3 had three specific failures the triage rubric fixes:

1. **Score gaming.** Auditors (and the model) would softly relabel a
   Critical as a High to get under the band threshold. The rubric's
   verdict is triggered by *specific conditions*, not a sum, so
   relabeling doesn't help.

2. **Score noise.** Two auditors looking at the same findings could land
   at 67 vs 78 and disagree about the band. The rubric's verdict is
   deterministic given the findings.

3. **Score uselessness for action.** "76/100" doesn't tell the team how
   long the work is. The Remediation Plan does.

The cost of dropping the score: lost a comparable metric across audits.
That's fine. Audits aren't a leaderboard.
