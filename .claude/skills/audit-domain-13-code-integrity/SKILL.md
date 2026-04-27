---
name: audit-domain-13-code-integrity
description: Audit code integrity and coherence — duplication, hallucinated references, Tambon signatures, spec drift, Frankenstein patterns, mystery code. THIS DOMAIN incorporates findings from the Tambon hunt and most of the blind-spots walk. Run as part of /audit Phase E.
---

# Skill: Audit Domain 13 — Code Integrity & Coherence (LLM-failure-mode domain)

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
- Blind spots that route to this domain: B9, B12, B13, B14

If the orchestrator didn't pass you these inputs, do NOT re-run the
hard-stops or blind-spots walks. Audit your domain only and trust the
orchestrator to stitch.

## Scope

Duplication (Type-1 through Type-4 clones), hallucinated references, Tambon signatures (already counted in Phase C), spec-vs-code drift, Frankenstein patterns (multiple HTTP clients, multiple state libs), mystery code (unowned, unreferenced), test-mirrors-code patterns.

## Key questions to answer

For each, find the evidence and report it. The questions are the
audit's spine — every finding maps back to one of them.

1. Tambon density: how many LLM-specific signatures per kLoC?
2. Are there duplicate functions / endpoints / utilities?
3. Are there imports of packages not in the manifest?
4. Do comments match the code?
5. Are tests asserting behavior or implementation?
6. How many 'utility' / 'helpers' / 'lib' directories exist?
7. Are there modules nothing imports?

## Files most likely to have findings

Don't read everything. Read these files first:

- all 'utils' / 'helpers' / 'lib' / 'common' / 'shared' modules
- the dependency manifest (cross-referenced with imports)
- test files in critical-flow modules

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
  DOMAIN 13: Code Integrity & Coherence (LLM-failure-mode domain)
═══════════════════════════════════════════════════════════════════════

▶ FOUNDER VIEW

[2-4 sentences in plain English. Sample tone:]
How coherent is the codebase as a whole? Vibe-coded apps often look fine file-by-file but are incoherent overall — this domain catches that.

▶ TECHNICAL EVIDENCE

Scope of this domain audit:
  Files read:        <count>
  Files skipped:     <count> (reason: outside scope or low-priority)

Findings:

  F-13.1 — <one-line title>
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
      <one paragraph; for full fix prompt, use /audit-fix F-13.1>

    Verification after fix:
      <command>

  F-13.2 ...

Summary:
  Total findings: <count>
  By severity:    <counts>
  Most urgent:    <which finding ID>

[SECTION COMPLETE: Domain 13]
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

## Mandatory: critical flow trace

For EVERY business-critical flow (auth, payments, deletes, data export),
trace it from entry point to side effect using only the code. If the
trace cannot be completed without the original developer's knowledge,
that flow is **unowned** and is a finding.

Format the trace as:

```
FLOW: <auth login | payment webhook | account delete | data export | etc.>

  Entry:        <path:line> — <one-line description>
  Validates:    <path:line> — <what's validated>
  Authorizes:   <path:line> — <what auth check>
  Mutates:      <path:line> — <what side effect>
  Returns:      <path:line> — <what response>

  Trace status: COMPLETE | PARTIAL — could not determine <X>
```

A PARTIAL trace is itself a finding. Severity scales with the flow's
criticality (auth/payment partials = High; export partials = Medium).

## Tambon density rollup

This domain section also includes the Tambon density figure from Phase C
(audit-tambon-hunt). Format:

```
Tambon Density: <X> per 1000 LoC
Density band:   <one of the four bands from audit-tambon-signatures.md>
Implication:    <one sentence>
```

Critical-path Tambon findings (those in auth/payment/delete code) are
listed in this domain's findings section.

## Failure modes to refuse

- ❌ Producing findings without path:line citations (R1)
- ❌ Citing a path you didn't read (R2)
- ❌ Re-running hard-stops or blind-spots walks (orchestrator did this)
- ❌ Including findings outside this domain's scope (route them to the
  right domain instead)
- ❌ Soft-pedaling a Critical to Medium because "it's a small app" (R3)
- ❌ Skipping section completion marker (R6)
