---
name: audit-domain-04-devops
description: Audit the infra and DevOps domain — CI/CD, deployment, IaC, secrets management, environments, logging, observability. Run as part of /audit Phase E.
---

# Skill: Audit Domain 4 — Infrastructure & DevOps

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

- Hard stops related to this domain: H4
- Blind spots that route to this domain: B5

If the orchestrator didn't pass you these inputs, do NOT re-run the
hard-stops or blind-spots walks. Audit your domain only and trust the
orchestrator to stitch.

## Scope

CI/CD pipelines, deployment scripts, Infrastructure-as-Code, secrets management, environment configuration (dev/staging/prod), logging, observability, monitoring, on-call.

## Key questions to answer

For each, find the evidence and report it. The questions are the
audit's spine — every finding maps back to one of them.

1. Is the deployment process scripted and version-controlled, or manual?
2. Are secrets handled by a real secret manager, or env vars on disk?
3. Are environments (dev/staging/prod) properly isolated?
4. Is logging centralized and searchable?
5. Are basic metrics (request rate, error rate, p50/p95 latency) collected?
6. Is there an on-call setup / alerting?
7. Are CI workflows tested as part of code review?

## Files most likely to have findings

Don't read everything. Read these files first:

- .github/workflows/ or equivalent
- Dockerfile / docker-compose.yml
- deployment scripts
- env example files
- logging config

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
  DOMAIN 4: Infrastructure & DevOps
═══════════════════════════════════════════════════════════════════════

▶ FOUNDER VIEW

[2-4 sentences in plain English. Sample tone:]
What happens when you push to main? What happens at 3am when it breaks? This is operational maturity.

▶ TECHNICAL EVIDENCE

Scope of this domain audit:
  Files read:        <count>
  Files skipped:     <count> (reason: outside scope or low-priority)

Findings:

  F-4.1 — <one-line title>
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
      <one paragraph; for full fix prompt, use /audit-fix F-4.1>

    Verification after fix:
      <command>

  F-4.2 ...

Summary:
  Total findings: <count>
  By severity:    <counts>
  Most urgent:    <which finding ID>

[SECTION COMPLETE: Domain 4]
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



## Failure modes to refuse

- ❌ Producing findings without path:line citations (R1)
- ❌ Citing a path you didn't read (R2)
- ❌ Re-running hard-stops or blind-spots walks (orchestrator did this)
- ❌ Including findings outside this domain's scope (route them to the
  right domain instead)
- ❌ Soft-pedaling a Critical to Medium because "it's a small app" (R3)
- ❌ Skipping section completion marker (R6)
