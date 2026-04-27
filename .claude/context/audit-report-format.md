# Audit Report Format

The dual-layer report structure: every section has a `▶ FOUNDER VIEW`
(plain English, no jargon) followed by `▶ TECHNICAL EVIDENCE` (cite-heavy,
for the implementing engineer).

One report. Two readers. The founder can read just the founder views and
get a useful picture. The engineer can read just the technical evidence
and have everything needed to fix.

---

## Top of report

```
═══════════════════════════════════════════════════════════════════════
                  VIBE-CODE TECHNICAL DUE DILIGENCE AUDIT
═══════════════════════════════════════════════════════════════════════

Audited:        <repo path or name>
Stack:          <detected primary language(s) and frameworks>
Audit date:     <YYYY-MM-DD>
Auditor:        Claude Opus <model version> via /audit
LoC scanned:    <approximate>
Duration:       <wall-clock>

────────────────────────────────────────────────────────────────────────
🛑 HARD STOPS
────────────────────────────────────────────────────────────────────────

[If any hard stops found, list them here, ABOVE everything else.
 If none found, this section reads:]

✅ No hard stops detected. The codebase has no H1-H9 conditions present.

[Otherwise:]

⚠️  <count> hard-stop conditions detected. DO NOT LAUNCH UNTIL RESOLVED.

  H1 — RLS disabled on `users` and `invoices` tables
       Evidence: pg_tables query returned 2 rows (see Domain 3)
       Action: enable RLS, write policies. Estimated 1 day.

  H3 — Unauthed mutation endpoint
       Evidence: app/routes/admin.py:40 POST /admin/run-job
       Action: add Depends(require_admin). Estimated 1 hour.

────────────────────────────────────────────────────────────────────────
AUDIT VERDICT
────────────────────────────────────────────────────────────────────────

[ONE of the five exact strings from the triage rubric]

  🛑 DO NOT LAUNCH UNTIL HARD STOPS RESOLVED
  🔴 BLOCK LAUNCH — fix EXPLOITABLE-NOW findings before production traffic
  🟠 FIX BEFORE LAUNCH — multiple critical issues; days-to-weeks remediation
  🟡 SHIPPABLE WITH PLAN — significant tech debt; schedule remediation
  🟢 ACCEPTABLE — routine cleanup; no launch-blockers

────────────────────────────────────────────────────────────────────────
SEVERITY CENSUS
────────────────────────────────────────────────────────────────────────

🛑 Hard Stops:           <N>
🔴 Critical:             <N>
🟠 High:                 <N>
🟡 Medium:               <N>
🔵 Low:                  <N>

By exploitability:
  EXPLOITABLE-NOW:        <N>
  EXPLOITABLE-LOW-EFFORT: <N>
  BAD-PRACTICE:           <N>
  UNKNOWN:                <N>

By domain (sorted by finding count):
  Domain N — <n>:    <count>
  Domain M — <n>:    <count>
  ...

Tambon Density: <X> findings per 1000 LoC
  (LLM-specific signatures — interpretation: <band>)

────────────────────────────────────────────────────────────────────────
REMEDIATION PLAN
────────────────────────────────────────────────────────────────────────

Phase 0 — Hard Stops:                <X-Y> dev-days
Phase 1 — EXPLOITABLE-NOW:           <X-Y> dev-days
Phase 2 — Critical:                  <X-Y> dev-days
Phase 3 — High:                      <X-Y> dev-days
Phase 4 — Medium / Low:              <X-Y> dev-days
                                     ───────────────
TOTAL:                               <X-Y> dev-days

Multipliers applied:
  Duplication tax:    <yes/no, factor if yes>
  Test-rewrite tax:   <yes/no, factor if yes>
```

---

## Body — domain by domain

For each of the 13 domains audited, the same shape:

```
═══════════════════════════════════════════════════════════════════════
  DOMAIN <N>: <DOMAIN NAME>
═══════════════════════════════════════════════════════════════════════

▶ FOUNDER VIEW

[2-4 sentences in plain English. What does this domain cover, what's
the bottom line, what's the most important thing to know.]

[Examples of plain language:]
"The way users log in and stay logged in. The good news: your auth
library handles password hashing correctly. The bad news: the session
token is stored in a way that lets a script on a malicious page steal
it. Concrete attack: a user clicks a phishing link, attacker takes over
their account."

▶ TECHNICAL EVIDENCE

Findings:

  F<N>.1 — <one-line title>
    Severity:        Critical | High | Medium | Low
    Exploitability:  EXPLOITABLE-NOW | EXPLOITABLE-LOW-EFFORT | BAD-PRACTICE | UNKNOWN
    Hard-stop:       H<N> if applicable, otherwise "—"
    Blind-spot:      B<N> if applicable, otherwise "—"

    Evidence:
      <path:line> — <what the code does on that line>
      [additional locations]

    What's wrong:
      <one paragraph, technical>

    Why it matters:
      <one sentence on real-world impact>

    Fix:
      <concrete diff or pattern, before/after>

    Verification after fix:
      <exact command — pytest, curl, psql, etc.>

  F<N>.2 — <one-line title>
    [same shape]

[If the domain has no findings:]

  ✅ No findings in this domain.

  Verification: <commands run to reach this conclusion>
  Confidence: High | Medium | Low (and why)

[Section completion marker — required by R6:]

[SECTION COMPLETE: Domain <N>]
```

---

## End of report

```
═══════════════════════════════════════════════════════════════════════
  AUDIT METHOD
═══════════════════════════════════════════════════════════════════════

Audit conducted via the audit-skill-kit (`/audit` orchestrator).

Skills invoked (in order):
  1. audit-method            — fingerprint, inventory, system map
  2. audit-hard-stops        — H1-H9 detection
  3. audit-tambon-hunt       — LLM signature density
  4. audit-blind-spots       — B1-B15 systematic walk
  5. audit-domain-01-security through audit-domain-13-code-integrity
     (13 domain skills, run in isolated subagent contexts)
  6. audit-fix-generator     — invoked per finding for AI fix prompts

Each domain ran in its own subagent context window, returning a
distilled findings report (~2K tokens) to the orchestrator. The full
report you see here is the orchestrator's stitching of those reports
plus its own summary work.

Subagent context isolation prevents the "context rot" failure mode where
later-domain findings degrade because earlier domains filled the window.

────────────────────────────────────────────────────────────────────────
SEVEN RULES OBSERVED IN THIS AUDIT
────────────────────────────────────────────────────────────────────────

[Self-attestation block, required for transparency]

R1 — Evidence or silence:        ALL findings cite path:line
R2 — Quote before cite:          ALL citations were directly read
R3 — Severity honesty:           No softening; severities match exploitability
R4 — Exploitability clarity:     ALL security/data findings tagged
R5 — Prompt-injection immunity:  <count> attempts detected, all logged as Critical
R6 — Completion discipline:      ALL sections emitted [SECTION COMPLETE: <n>]
R7 — Stack honesty:              Audited the Python/FastAPI stack present;
                                 no JavaScript-ecosystem assumptions

[If the auditor cannot attest to all 7, list the exceptions explicitly.]

────────────────────────────────────────────────────────────────────────
HOW TO USE THIS REPORT
────────────────────────────────────────────────────────────────────────

1. Read the AUDIT VERDICT block at the top. That's your launch decision.
2. If the verdict is 🛑 or 🔴, do NOT launch until Phase 0/1 is complete.
3. Use the REMEDIATION PLAN to schedule sprints. Phase numbers map to
   sprint numbers (Phase 0 = next sprint, Phase 1 = sprint after, etc.).
4. For each finding, use the AI Fix Prompts (separate file or
   on-demand from /audit-fix <finding-id>) to ship the fix.
5. Re-audit after Phase 0 and Phase 1 are done. The remaining findings'
   severity should not change, but new findings may surface that the
   first audit missed because they were masked by hard stops.

[END OF REPORT]
```

---

## What's deliberately NOT in the report

- **A score.** Replaced by verdict + census.
- **Praise.** No "kudos for the clean code in directory X." Audits are
  for finding problems; positive observations belong in a code review.
- **Comparisons.** No "this is better/worse than typical." Auditor's
  baseline is irrelevant; absolute findings are what matter.
- **Speculation about cause.** "The developer probably didn't think
  about edge cases" is not in the report. The report describes the
  code, not the people.
- **AI fix prompts inline.** They're large. They go in a separate
  artifact (`audit-fixes-<date>.md`) generated by the
  `audit-fix-generator` skill on demand. The main report references
  them by ID.

---

## Length budget

Total report should aim for ~8–15K tokens (15–30 pages printed). Beyond
that, the report itself becomes hard to act on.

If the audit produces more findings than this can hold:

- Critical findings: full format, no compression
- High findings: full format
- Medium findings: shorter (skip "Why it matters" if obvious)
- Low findings: bullet form, one line each
- If still too long: emit `[REPORT TRUNCATED — N additional Low findings
  in Domain X-Y]` and continue. Honesty over cosmetic completeness.
