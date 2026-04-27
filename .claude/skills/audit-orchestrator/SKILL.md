---
name: audit-orchestrator
description: Conduct a full technical due diligence audit of a vibe-coded codebase. Use when the user types `/audit`, asks for a "full audit," asks for a "due diligence review," asks "is this codebase ready to ship?", or asks for a comprehensive code review of an entire repository (not a single PR). Coordinates the 13 domain skills, the hard-stop hunt, the Tambon LLM-signature hunt, and the blind-spot walk. Produces a single dual-layer report (founder view + technical evidence).
---

# Skill: Audit Orchestrator

You are the conductor of a multi-domain technical due diligence audit.
Your job is sequencing, not finding. The actual hunting happens in
specialized skills and subagents that you invoke and stitch together.

This is a long-running, multi-phase task. Before doing anything, plan
the run.

---

## What this skill produces

A single report following the format in
`@.claude/context/audit-report-format.md`. Founder view + technical
evidence, with severity census, verdict, and remediation plan at the top
and 13 domain sections below.

---

## What this skill does NOT do

- Find findings directly. The domain skills do that.
- Modify any code. Read-only audit.
- Produce AI fix prompts for every finding inline. The
  `audit-fix-generator` skill does that on demand.
- Deliver a partial audit silently. If running out of context, emit a
  truncation marker per Rule R6.

---

## Pre-flight (do once, at the start)

Before invoking any other skill, do this in order:

### 1. Load the rules

Read `@.claude/context/audit-rules.md` end-to-end. The seven rules
(R1-R7) apply to the entire audit.

### 2. Load the report format

Read `@.claude/context/audit-report-format.md`. You're going to be
producing this format; familiarize yourself.

### 3. Load the triage rubric

Read `@.claude/context/audit-triage-rubric.md`. The verdict at the top
of the report is determined by the rules in this file.

### 4. Confirm scope with the user (one short question)

If the user said `/audit` with no scope, ask:

> "I'll run the full audit on this repository. Confirm:
> (a) the entire repo, or (b) a specific subtree (e.g., `src/services/`)?"

Default to (a) if they said `/audit` alone. If they specified a path,
use that as the audit scope.

### 5. Detect the stack (R7 enforcement)

Run the audit-method skill phase 1 (tool fingerprinting) to confirm:

- Primary language(s)
- Web framework(s)
- Database(s)
- Auth approach (cookie session, JWT, OAuth, custom)
- Deployment target (if detectable from config)

Record this. The domain skills use it. R7 ("stack honesty") forbids
projecting framework conventions from a different stack.

---

## Run order

Execute these phases in order. Do not skip. Do not reorder.

```
PHASE A — METHOD
  ├─ audit-method skill
  │    ├─ Phase 1: Tool fingerprinting        (already done in pre-flight)
  │    ├─ Phase 2: Repository inventory
  │    └─ Phase 3: System mapping (high-level architecture)
  │
  └─ Output: a written model of "what this codebase is and how it's wired"
     (3-5 paragraphs, kept in your context for the rest of the audit)

PHASE B — HARD STOPS (runs FIRST after method)
  ├─ audit-hard-stops skill
  │    └─ Walks H1-H9 systematically
  │
  └─ Output: list of FOUND / NOT FOUND for each H1-H9
     (If any FOUND, the report's verdict is locked to 🛑)

PHASE C — TAMBON SIGNATURES
  ├─ audit-tambon-hunt skill
  │    └─ Scans for Hallucinated Object / Wrong Attribute / Silly Mistake
  │
  └─ Output: signature counts + density per 1000 LoC
     (Findings flow into Domain 13)

PHASE D — BLIND SPOTS
  ├─ audit-blind-spots skill
  │    └─ Walks B1-B15 systematically
  │
  └─ Output: PRESENT / NOT PRESENT for each B1-B15
     (Findings flow into the appropriate domain)

PHASE E — DOMAIN AUDITS (13 skills, IN ISOLATED SUBAGENT CONTEXTS)
  │
  │  Use the `audit-domain-runner` subagent. Spawn ONE subagent per
  │  domain. Each subagent loads the domain skill and the audit-rules,
  │  runs against the audit scope, returns a ~2K-token findings report.
  │
  │  Why subagents:
  │    - Each domain gets a clean context window (no cross-contamination)
  │    - Heavy file reads stay in subagent context, not main
  │    - Parallelism (subagents can run concurrently if Claude Code allows)
  │
  ├─ audit-domain-01-security
  ├─ audit-domain-02-architecture
  ├─ audit-domain-03-database
  ├─ audit-domain-04-devops
  ├─ audit-domain-05-performance
  ├─ audit-domain-06-ux-a11y
  ├─ audit-domain-07-reliability
  ├─ audit-domain-08-compliance
  ├─ audit-domain-09-maintainability
  ├─ audit-domain-10-cost
  ├─ audit-domain-11-demo-vs-prod
  ├─ audit-domain-12-missing
  └─ audit-domain-13-code-integrity
       (this domain incorporates the Tambon and blind-spot findings)

PHASE F — STITCH THE REPORT
  │
  ├─ Compute severity census (sum across all phases)
  ├─ Determine verdict from triage rubric (deterministic, not your call)
  ├─ Compute remediation estimates per phase
  ├─ Assemble the final report per audit-report-format.md
  ├─ Run the R1-R7 self-attestation block
  └─ Emit the complete report

PHASE G — SELF-CHECK (mandatory, per R6)
  │
  ├─ Verify every finding has a path:line citation
  ├─ Verify every Critical/High has an exploitability tag
  ├─ Verify the verdict matches the triage rubric (it's deterministic)
  ├─ Verify [SECTION COMPLETE: Domain <N>] markers are present for all 13
  └─ Emit [AUDIT COMPLETE] or [AUDIT TRUNCATED] honestly
```

---

## How to invoke each phase

**Phase A (audit-method):**

> "Use the audit-method skill to fingerprint and inventory the
> codebase at `<scope>`. Return: detected stack, repo structure
> summary, system map. Do not produce findings yet."

**Phase B (audit-hard-stops):**

> "Use the audit-hard-stops skill to walk H1-H9 against `<scope>`.
> For each, run the detection commands from
> `@.claude/context/audit-hard-stops.md`. Return: status (FOUND /
> NOT FOUND / UNABLE) per H-class with evidence."

**Phase C (audit-tambon-hunt):**

> "Use the audit-tambon-hunt skill to scan `<scope>` for the three
> Tambon signatures. Use mypy / pyright / tsc as appropriate. Return:
> counts per signature, top occurrences, density per 1000 LoC."

**Phase D (audit-blind-spots):**

> "Use the audit-blind-spots skill to walk B1-B15 against `<scope>`.
> Return: PRESENT / NOT PRESENT per B-class with evidence."

**Phase E (each domain):**

For each of the 13 domains, spawn a subagent:

> "Use the audit-domain-runner subagent. Pass it: domain=<N>, scope=`<path>`,
> stack=<from method>, hard-stops-found=<list>, tambon-density=<X>,
> blind-spots-present=<list>. The subagent will load
> audit-domain-0<N>-<name>/SKILL.md and produce a domain findings
> report. Return only the findings report, no commentary."

If your environment supports parallel subagent execution, dispatch all
13 in parallel. Otherwise, dispatch sequentially. Either way, each
subagent has its own clean context window — they don't interfere with
each other or with you.

**Phase F (stitching):**

This phase happens in your context (the orchestrator). You receive 13
domain reports + the hard-stops, Tambon, and blind-spots reports. You
stitch them into the format from `@.claude/context/audit-report-format.md`.

Be a stitcher, not an editor. Do not soften findings the domains
emitted. Do not re-rank severities. The verdict is determined by the
triage rubric — apply it mechanically.

**Phase G (self-check):**

Walk the checklist at the bottom of audit-report-format.md. Emit one of:

- `[AUDIT COMPLETE: all 7 rules attested, all 13 domains covered]`
- `[AUDIT TRUNCATED: <reason>]`

---

## Context budget management

The full audit is unavoidably large. Strategies to stay under
degradation thresholds:

1. **Subagents are mandatory.** The 13 domains MUST run in subagents.
   Running them in the main context will fill ~500K tokens by Domain 6.

2. **Don't re-read the rules per domain.** The audit-rules.md is loaded
   once in pre-flight. The domain subagents load it themselves; you
   don't pass it as input.

3. **Don't accumulate raw findings.** When a domain returns its report
   (~2K tokens), keep the structured findings (severity, location,
   description). Discard the working notes the subagent might include.

4. **Compact between phases.** After Phase E completes, your context
   has 13 domain reports + hard-stops + Tambon + blind-spots. Before
   Phase F, write a compact summary to a scratch file:
   `.claude/audit-runs/<timestamp>/findings.json`. Then in Phase F,
   read from that file. Keeps the main context lean.

5. **Stitch incrementally.** The report has a top section (verdict,
   census, plan) and a body (13 domains). Emit them progressively —
   don't hold the full 30-page report in your head before writing it.

---

## When to ask the user vs proceed

**Ask:**
- Scope is genuinely ambiguous (different subtrees with different stacks)
- A hard stop requires runtime info to verify (e.g., "is this RLS
  policy active in production?") — flag as `[UNVERIFIED]`, ask if
  runtime access is possible
- The audit is going to take >20 minutes wall-clock — confirm before
  starting

**Proceed:**
- Standard `/audit` on a clear repo
- Stack detection succeeds (don't need user to tell you it's Python)
- Subagents return reports in expected shape (don't ask "should I use
  this report?" — use it)

---

## Failure modes to refuse

- ❌ Producing the report without running the domain skills (writing
  from imagination — this is what v3's monolithic prompt risked)
- ❌ Skipping the hard-stops phase (it MUST run, even if domains are
  truncated)
- ❌ Stitching findings the subagents didn't produce
- ❌ Soft-pedaling the verdict ("mostly fine" when there's an
  EXPLOITABLE-NOW finding)
- ❌ Citing a path you didn't see (R2 — "quote before cite")
- ❌ Emitting `[AUDIT COMPLETE]` if any domain truncated

---

## A note on time

A real `/audit` of a typical 50K-LoC codebase takes:

- Pre-flight + method:  3–5 minutes
- Hard stops:           5–8 minutes
- Tambon hunt:          3–5 minutes (mostly waiting for type-checker)
- Blind spots:          5–8 minutes
- 13 domain subagents:  20–40 minutes (mostly parallel if possible)
- Stitching:            5 minutes
- Total:                40–70 minutes wall-clock

Tell the user this up front so they don't expect it in 30 seconds.
