---
name: audit-domain-09-maintainability
description: Audit the dev experience and maintainability — local setup, documentation, test quality, CI feedback time, debuggability. Run as part of /audit Phase E.
---

# Skill: Audit Domain 9 — Developer Experience & Maintainability

This skill audits one specific domain. It runs in an isolated subagent
context spawned by the audit-orchestrator. The subagent loads this
skill and the audit rules, runs against the audit scope, and returns
a ~2K-token findings report.

## Pre-flight

```
view @.claude/context/audit-rules.md
```

If you have findings from previous audit phases (hard stops, Tambon,
blind spots), the orchestrator passes them as input. Use them — don't
re-discover findings other phases already produced. Specifically:

- Hard stops related to this domain: H9
- Blind spots that route to this domain: B9, B13, B14, B15

If the orchestrator didn't pass you these inputs, do NOT re-run the
hard-stops or blind-spots walks. Audit your domain only and trust the
orchestrator to stitch.

## Scope

Local setup ease (README clarity, Docker compose, seed data), code documentation, test quality (not just coverage), CI feedback time, debuggability, onboarding time for new contributors.

## Key questions to answer

For each, find the evidence and report it. The questions are the
audit's spine — every finding maps back to one of them.

1. Can a new developer run the app locally in <30 minutes from clone?
2. Are tests fast enough to run on every commit?
3. Do tests test behavior, not implementation?
4. Are there integration tests, or just unit tests with mocks?
5. Are public functions documented?
6. Is there a CONTRIBUTING.md or similar?

## Files most likely to have findings

Don't read everything. Read these files first:

- README.md
- CONTRIBUTING.md
- test infrastructure (conftest.py, jest.config, etc.)
- docker-compose.yml for dev

If you exhaust these and the budget allows, expand outward. Otherwise,
report what you found and note what you didn't read.

## Process

1. **Re-read the rules.** R1-R7 apply to every finding. Especially R2
   (quote before cite) — for a domain skill running in a subagent, the
   subagent's context is fresh; don't assume you remember a file from
   a previous turn.

2. **Walk the key questions.** For each question, run the relevant
   detection commands (greps, file reads, schema lookups). Capture
   evidence at path:line. Verify by reading the actual code.

3. **Cross-reference orchestrator inputs.** If the orchestrator passed
   hard-stops or blind-spots findings tagged for this domain, include
   them in your report. Don't re-investigate; just include with the
   provided evidence.

4. **Triage.** For each finding, set severity per the audit rubric and
   exploitability per R4.

5. **Produce the domain report.**

## Output format

```
═══════════════════════════════════════════════════════════════════════
  DOMAIN 9: Developer Experience & Maintainability
═══════════════════════════════════════════════════════════════════════

▶ FOUNDER VIEW

[2-4 sentences in plain English. Sample tone:]
If your current developer leaves, can the next one pick it up — or is the codebase only legible to its author?

▶ TECHNICAL EVIDENCE

Scope of this domain audit:
  Files read:        <count>
  Files skipped:     <count> (reason: outside scope or low-priority)

Findings:

  F-9.1 — <one-line title>
    Severity:        Critical | High | Medium | Low
    Exploitability:  EXPLOITABLE-NOW | EXPLOITABLE-LOW-EFFORT | BAD-PRACTICE | UNKNOWN
    Hard-stop:       H<N> if applicable
    Blind-spot:      B<N> if applicable

    Evidence:
      <path:line>  <one-line description>

    What's wrong:
      <one paragraph>

    Why it matters:
      <one sentence>

    Recommended fix:
      <one paragraph; for full fix prompt, use /audit-fix F-9.1>

    Verification after fix:
      <command>

  F-9.2 ...

Summary:
  Total findings: <count>
  By severity:    <counts>
  Most urgent:    <which finding ID>

[SECTION COMPLETE: Domain 9]
```

If the domain has zero findings:

```
▶ TECHNICAL EVIDENCE

  ✅ No findings in this domain.

  Verification:
    <commands run that produced no signal>

  Confidence: High | Medium | Low
  Reason for low confidence: <if applicable>
```

## Mandatory: maintainability interview test

Inside this domain, answer ALL FIVE using only repository evidence:

1. Where is the session token stored, and how is it invalidated on logout?
2. Trace a payment webhook from HTTP request to database write — name the file that validates the signature, the file that writes the row, the function that handles retries.
3. How is user data isolated? Can User A see User B's data by changing an ID in the URL?
4. What is the deployment process from code commit to production? Is it in version control?
5. Where are environment-specific configurations, and how do they differ between dev and prod?

If any answer is "cannot determine from code," that is itself a finding.
Each unanswerable question = at least Medium severity, because it
implies the codebase is unowned (only the original author understands
it). Three or more unanswerable = High.

## Failure modes to refuse

- ❌ Producing findings without path:line citations (R1)
- ❌ Citing a path you didn't read (R2)
- ❌ Re-running hard-stops or blind-spots walks (orchestrator did this)
- ❌ Including findings outside this domain's scope (route them to the
  right domain instead)
- ❌ Soft-pedaling a Critical to Medium because "it's a small app" (R3)
- ❌ Skipping section completion marker (R6)
