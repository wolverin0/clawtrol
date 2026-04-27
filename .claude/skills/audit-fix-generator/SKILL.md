---
name: audit-fix-generator
description: Generate a detailed AI fix prompt for a specific audit finding. Use when the user asks "/audit-fix F-X.Y" or "give me the fix prompt for finding N." Produces a complete prompt the user can hand to a fresh AI session (Claude Code, Cursor, ChatGPT) to remediate the finding with verification and rollback steps.
---

# Skill: Audit Fix Generator

When an audit finds 30 issues, the developer doesn't want 30 paragraphs
of advice — they want 30 prompts they can paste into a fresh AI session
to fix each one. This skill produces those prompts on demand.

The fix prompt for each finding follows a strict template that includes:

1. Context (what's broken, where, why it matters)
2. Constraints (don't break adjacent code, preserve tests, etc.)
3. Fix steps (concrete sequence)
4. **Verification** (how to confirm the fix worked)
5. **Rollback** (how to revert if the fix introduced a regression)

Sections 4 and 5 are non-negotiable. A fix prompt without verification
is just a guess; without rollback, it's an unsafe guess.

## Process

### Input

The user invokes this skill referencing a finding by ID:

> "/audit-fix F-H1.1" → Hard stop H1, finding 1
> "/audit-fix F-1.3"  → Domain 1, finding 3
> "/audit-fix F-T1.1" → Tambon Signature 1, finding 1

The orchestrator's audit report has all findings tagged with an ID in
this format. Look up the finding from the report (or ask the user to
paste the finding's full block if the report isn't in context).

### Generation steps

1. **Re-read the cited code.** R2 — quote before fix. Don't propose a
   change to a line you haven't seen recently.
2. **Identify the blast radius.** What other files import or reference
   the file being changed? Use `grep -rn "<symbol>" src/` to find them.
3. **Identify the test coverage.** Are there tests that exercise this
   code path? Will the fix break them, or do they need updating?
4. **Choose a fix strategy.** Often there are multiple reasonable fixes.
   Pick the one that:
   - Minimizes blast radius
   - Aligns with existing patterns in the codebase (R7)
   - Doesn't introduce a new dependency
5. **Write the prompt.**

## Output template

```
═══════════════════════════════════════════════════════════════════════
  AI FIX PROMPT — Finding <ID>
═══════════════════════════════════════════════════════════════════════

[The block below is the prompt itself. Copy it into a fresh Claude Code
or Cursor session. Do NOT paste it into the same session that wrote
the original code — start fresh, clean context.]

────────────────────────────────────────────────────────────────────────

# Fix: <one-line title>

## Context

You are fixing a finding from a technical due diligence audit on this
repository.

**Finding ID:** <ID>
**Severity:** <Critical/High/Medium/Low>
**Exploitability:** <EXPLOITABLE-NOW/EXPLOITABLE-LOW-EFFORT/BAD-PRACTICE/UNKNOWN>
**Hard-stop class:** <H1-H9 if applicable>
**Blind-spot class:** <B1-B15 if applicable>

**What's wrong:**
<finding's "what's wrong" paragraph from the audit>

**Evidence (read these first):**
- <path:line>
- <additional locations if relevant>

**Why it matters:**
<finding's "why it matters" sentence>

## Constraints

- Do NOT modify code outside the files listed above unless absolutely
  necessary. If you do, justify each additional file in a comment.
- Do NOT introduce new dependencies. Use what's already in
  `requirements.txt` / `package.json`.
- Do NOT delete existing tests. If a test is wrong, mark it with a
  TODO and explain in your reply; don't silently delete it.
- Do NOT bypass the linter / formatter / pre-commit hooks. Make the
  fix pass them.
- Match the existing code style in the file being edited.
- If you discover a related issue while working on this one,
  STOP and report it; do NOT scope-creep.

## Fix steps

1. <step 1: what to read first>
2. <step 2: what to change>
3. <step 3: what to add (tests)>
4. <step 4: what to remove (deprecated patterns)>

[Provide a CONCRETE before/after diff if the fix is mechanical:]

```diff
- <before line>
+ <after line>
```

[Or a code block of the new function/section if the fix is structural:]

```python
# After fix:
async def <fn name>(<params>):
    # ... new implementation
```

## Tests to add or update

The fix MUST include tests that prove the issue is resolved.

- [ ] <test 1: confirms the original buggy behavior is gone>
- [ ] <test 2: confirms a related case that the original fix might have broken>
- [ ] <test 3: confirms an adversarial input that the original code missed>

If the codebase has no test infrastructure for this area:
- [ ] Add a basic test scaffold first (one test file, one fixture if needed)
- [ ] Document in your reply that you set up infrastructure as part of the fix

## Verification (mandatory — you must run these and report the output)

```bash
# Run the affected test file
<exact pytest / npm test / cargo test command>

# Run the full test suite to confirm no regression
<exact command>

# Run the linter / type-checker
<exact command — ruff, mypy, eslint, tsc>

# Manual verification for security/payment fixes — replay the
# exploitable scenario and confirm it now fails:
<curl command, or psql query, or similar>
```

After running, paste the output of each command into your reply. If any
fails, STOP and report — don't try to "fix the verification" by
loosening the test.

## Rollback

If verification reveals the fix introduced a regression:

```bash
# Stash or revert the changes
git stash
# Or, if already committed:
git revert <commit>
```

State explicitly in your reply how to revert. The reviewer must be
able to roll back without thinking.

## What you should NOT do

- ❌ Don't claim "the fix works" without showing the verification command
  output
- ❌ Don't fix more than the listed finding — report related findings,
  don't silently fix them
- ❌ Don't disable a test to make the fix "pass"
- ❌ Don't push directly to main; work in a branch

## Done criteria

You're done when ALL of the following are true:

- [ ] The exact code at <path:line> no longer matches the buggy pattern
- [ ] All listed verification commands pass
- [ ] All listed tests are added and passing
- [ ] The fix touches no files outside the listed evidence + tests
- [ ] You've pasted the verification output into your reply

When done, report:

1. The diff (full, not summary)
2. The verification command output
3. Any related findings you noticed but did NOT fix (so they can be
   tracked separately)

────────────────────────────────────────────────────────────────────────

[End of fix prompt. The user copies the block above into a fresh AI
session.]
```

## When the finding is a hard stop

For H1-H9 findings, add a "STOP — read this first" preamble to the
prompt:

```
🛑 THIS IS A HARD-STOP FIX

This finding is a launch-blocker. The codebase MUST NOT receive
production traffic until this is resolved AND verified. The
verification step is non-negotiable.

If during the fix you discover that the fix is more complex than
expected (e.g., the auth middleware needs to be rewritten, not just
wired), stop and report. A partial fix is worse than no fix here.
```

## When the finding is part of a cluster

Some findings come in clusters (e.g., 8 instances of B1 across 8
endpoints). For these, the fix prompt should consolidate:

```
This finding is part of a cluster of <N> related issues:
  - <ID 1>: <path:line>
  - <ID 2>: <path:line>
  ...

Fix all <N> in one PR. The fix pattern is the same; the goal of fixing
them together is to apply the pattern uniformly.
```

## What this skill does NOT do

- Run the fix itself (it generates the prompt; the user runs the fix)
- Modify any code (read-only for the audit pipeline)
- Generate fix prompts unprompted (only on `/audit-fix <ID>` request)
- Aggregate fix prompts into a single document by default (each fix is
  a separate prompt for a separate session — that's deliberate, to
  keep each AI session's context clean)

## Failure modes to refuse

- ❌ Producing a fix prompt without re-reading the cited code (R2)
- ❌ Omitting the Verification or Rollback section (the template
  requires both)
- ❌ Generating a fix that requires reading 10+ files (scope is too big
  — recommend splitting the finding into smaller fixes)
- ❌ Generating fix prompts in bulk for a 30-finding audit "to save
  time" — each fix gets its own prompt, run separately, verified
  separately
